import FIFOF::*;
import GetPut::*;
import Vector::*;
import Connectable::*;

import SemiFifo::*;
import PrimUtils::*;
import StreamUtils::*;
import PcieTypes::*;
import DmaTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import DmaUtils::*;
import CompletionFifo::*;

// TODO : change the PCIe Adapter Ifc to TlpData and TlpHeader, 
//        move the module which convert TlpHeader to IP descriptor from dma to adapter
interface DmaC2HPipe;
    // User Logic Ifc
    interface FifoIn#(DataStream)  wrDataFifoIn;
    interface FifoIn#(DmaRequest)  reqFifoIn;
    interface FifoOut#(DataStream) rdDataFifoOut;
    // Pcie Adapter Ifc
    interface FifoOut#(DataStream)     tlpDataFifoOut;
    interface FifoOut#(SideBandByteEn) tlpSideBandFifoOut;
    interface FifoIn#(StraddleStream)  tlpDataFifoIn;
    // TODO: Cfg Ifc
    // interface Put#(DmaConfig)   configuration;
    // interface Client#(DmaCsrValue, DmaCsrValue) statusReg;
endinterface

// Single Path module
(* synthesize *)
module mkDmaC2HPipe#(DmaPathNo pathIdx)(DmaC2HPipe);
    C2HReadCore  readCore  <- mkC2HReadCore(pathIdx);
    C2HWriteCore writeCore <- mkC2HWriteCore;

    FIFOF#(DataStream) dataInFifo   <- mkFIFOF;
    FIFOF#(DmaRequest) reqInFifo    <- mkFIFOF;
    FIFOF#(DataStream) tlpOutFifo   <- mkFIFOF;
    FIFOF#(SideBandByteEn) tlpSideBandFifo <- mkFIFOF;

    mkConnection(dataInFifo, writeCore.dataFifoIn);

    rule reqDeMux;
        let req = reqInFifo.first;
        reqInFifo.deq;
        if (req.isWrite) begin
            writeCore.wrReqFifoIn.enq(req);
        end
        else begin
            readCore.rdReqFifoIn.enq(req);
        end
        $display(" ");
        $display($time, "ns SIM INFO @ mkDmaC2HPipe%d: recv new request, startAddr:%d length:%d isWrite:%b",
                pathIdx, req.startAddr, req.length,  pack(req.isWrite));
    endrule

    rule tlpOutMux;
        if (readCore.tlpFifoOut.notEmpty) begin
            tlpOutFifo.enq(readCore.tlpFifoOut.first);
            tlpSideBandFifo.enq(readCore.tlpSideBandFifoOut.first);
            readCore.tlpSideBandFifoOut.deq;
            readCore.tlpFifoOut.deq;
        end
        else begin
            if (writeCore.tlpSideBandFifoOut.notEmpty) begin
                tlpSideBandFifo.enq(writeCore.tlpSideBandFifoOut.first);
                writeCore.tlpSideBandFifoOut.deq;
            end
            tlpOutFifo.enq(writeCore.tlpFifoOut.first);
            writeCore.tlpFifoOut.deq;
        end
    endrule

    // User Logic Ifc
    interface wrDataFifoIn  = convertFifoToFifoIn(dataInFifo);
    interface reqFifoIn     = convertFifoToFifoIn(reqInFifo);
    interface rdDataFifoOut = readCore.dataFifoOut;
    // Pcie Adapter Ifc
    interface tlpDataFifoOut      = convertFifoToFifoOut(tlpOutFifo);
    interface tlpSideBandFifoOut  = convertFifoToFifoOut(tlpSideBandFifo);
    interface tlpDataFifoIn       = readCore.tlpFifoIn;
    // TODO: Cfg Ifc

endmodule

interface C2HReadCore;
    // User Logic Ifc
    interface FifoOut#(DataStream)     dataFifoOut;
    interface FifoIn#(DmaRequest)      rdReqFifoIn;
    // PCIe IP Ifc, connect to Requester Adapter
    interface FifoIn#(StraddleStream)  tlpFifoIn;
    interface FifoOut#(DataStream)     tlpFifoOut;
    interface FifoOut#(SideBandByteEn) tlpSideBandFifoOut;
endinterface

// Total Latency(Tlp Output): 1 + 2 + 1 + 1 = 5
// Total Latency(Tlp Input) : 1\2 + 2 + n + 2 + 1 = 5/6 + n (depends on the order)
module mkC2HReadCore#(DmaPathNo pathIdx)(C2HReadCore);
    FIFOF#(StraddleStream) tlpInFifo      <- mkFIFOF;
    FIFOF#(DmaRequest)     reqInFifo      <- mkFIFOF;
    FIFOF#(DataStream)     tlpOutFifo     <- mkFIFOF;
    FIFOF#(SideBandByteEn) tlpByteEnFifo  <- mkFIFOF;

    FIFOF#(SlotToken)      tagFifo        <- mkSizedFIFOF(valueOf(TAdd#(1, STREAM_HEADER_REMOVE_LATENCY)));      
    FIFOF#(Bool)           completedFifo  <- mkSizedFIFOF(valueOf(TAdd#(1, STREAM_HEADER_REMOVE_LATENCY)));   
    FIFOF#(DmaMemAddr)     expectTlpCntFifo <-mkSizedFIFOF(valueOf(SLOT_PER_PATH));

    StreamPipe     descRemove     <- mkStreamHeaderRemove(fromInteger(valueOf(TDiv#(DES_RC_DESCRIPTOR_WIDTH, BYTE_WIDTH)))); 
    StreamPipe     dwRemove       <- mkStreamRemoveFromDW;
    StreamPipe     reshapeStrad   <- mkStreamReshape;
    StreamPipe     reshapeRcb     <- mkStreamReshape;
    StreamPipe     reshapeMrrs    <- mkStreamReshape;
    ChunkCompute   chunkSplitor   <- mkChunkComputer(DMA_RX);
    CompletionFifo#(SLOT_PER_PATH, DataStream)  cBuffer <- mkCompletionFifo(valueOf(MAX_STREAM_NUM_PER_COMPLETION));
    RqDescriptorGenerator rqDescGenerator <- mkRqDescriptorGenerator(False);
    
    Reg#(Bool) hasReadOnce <- mkReg(False);
    Reg#(DmaMemAddr) recvTlpCntReg <- mkReg(0);
    Reg#(DmaMemAddr) recvBytesReg  <- mkReg(0);
    Vector#(SLOT_PER_PATH, Reg#(DmaMemAddr)) chunkBytesRegs <- replicateM(mkReg(0));

    mkConnection(chunkSplitor.chunkCntFifoOut, expectTlpCntFifo);
    mkConnection(reshapeStrad.streamFifoOut, descRemove.streamFifoIn);
    mkConnection(descRemove.streamFifoOut, dwRemove.streamFifoIn);

    // Pipeline stage 1: convert StraddleStream to DataStream, may cost 2 cycle for one StraddleStream
    rule convertStraddleToDataStream;
        let sdStream = tlpInFifo.first;
        let stream   = getEmptyStream;
        SlotToken tag = 0;
        Bool isCompleted = False;
        if (sdStream.isDoubleFrame) begin
            PcieTlpCtlIsSopPtr isSopPtr = 0;
            if (hasReadOnce) begin
                tlpInFifo.deq;
                hasReadOnce <= False;
                isSopPtr = 1;
            end
            else begin
                hasReadOnce <= True;
            end
            stream = DataStream {
                data    : getStraddleData(isSopPtr, sdStream.data),
                byteEn  : getStraddleByteEn(isSopPtr, sdStream.byteEn),
                isFirst : sdStream.isFirst[isSopPtr],
                isLast  : sdStream.isLast[isSopPtr]
            };
            tag = sdStream.tag[isSopPtr];
            isCompleted = sdStream.isCompleted[isSopPtr];
        end
        else begin
            tlpInFifo.deq;
            hasReadOnce <= False;
            stream = DataStream {
                data    : sdStream.data,
                byteEn  : sdStream.byteEn,
                isFirst : sdStream.isFirst[0],
                isLast  : sdStream.isLast[0]
            };
            tag = sdStream.tag[0];
            isCompleted = sdStream.isCompleted[0]; 
        end
        stream.byteEn = stream.byteEn;
        reshapeStrad.streamFifoIn.enq(stream);
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: recv new stream from straddle adapter, tag: %d, isCompleted:%b" ,tag, isCompleted, fshow(stream));
        if (stream.isFirst) begin
            tagFifo.enq(tag);
            completedFifo.enq(isCompleted);
        end
        // $display("parse from straddle", fshow(stream));
    endrule

    // Pipeline stage 2: remove the descriptor in the head of each TLP

    // Pipeline stage 3: Buffer the received DataStreams and reorder them
    rule reorderStream;
        let stream = dwRemove.streamFifoOut.first;
        let byteInStream = convertByteEn2BytePtr(stream.byteEn);
        let isCompleted = completedFifo.first;
        let tag = tagFifo.first;
        let chunkBytes = zeroExtend(byteInStream) + chunkBytesRegs[tag];
        dwRemove.streamFifoOut.deq;
        if (stream.isLast) begin
            completedFifo.deq;
            tagFifo.deq;
        end
        stream.isLast = isCompleted && stream.isLast;
        cBuffer.append.enq(tuple2(tag, stream));
        if (stream.isLast) begin
            cBuffer.complete.put(tag);
            $display($time, "ns SIM INFO @ mkDmaC2HReadCore: a chunk is completed in cBuffer, tag: %d, recv bytes: %d", tag, chunkBytes);
            chunkBytes = 0;
        end
        chunkBytesRegs[tag] <= chunkBytes;
        $display("tag%d", tag, fshow(stream));
    endrule

    // Pipeline stage 4: there may be a bubble ibetween the first and last DataStream of cBUffer drain output
    //  Reshape the DataStream from RCB chunks to MRRS chunks
    rule reshapeRCB;
        let stream = cBuffer.drain.first;
        cBuffer.drain.deq;
        reshapeRcb.streamFifoIn.enq(stream);
        // $display("cbuf output", fshow(stream));
    endrule

    // Pipeline stage 4: there may be bubbles in the first and last DataStream of a request because of MRRS chunk compute
    //  Reshape the DataStream from MRRS chunks to a whole DataStream 
    rule reshapeMRRS;
        let stream = reshapeRcb.streamFifoOut.first;
        let byteInStream = convertByteEn2BytePtr(stream.byteEn);
        let recvBytesCnt = recvBytesReg + zeroExtend(byteInStream);
        reshapeRcb.streamFifoOut.deq;
        let recvTlpCnt = recvTlpCntReg;
        if (stream.isFirst) begin
            if (recvTlpCnt > 0) begin
                stream.isFirst = False;
            end
            recvTlpCnt = recvTlpCntReg + 1;
        end
        if (stream.isLast) begin
            if (expectTlpCntFifo.first == recvTlpCnt) begin
                recvTlpCnt = 0;
                expectTlpCntFifo.deq;
                $display($time, "ns SIM INFO @ mkDmaC2HReadCore: a read request is done, total tlps counts : %5d, total recvd bytes: %d", expectTlpCntFifo.first, recvBytesCnt);
                recvBytesCnt = 0;
            end 
            else begin
                stream.isLast = False;
            end
        end
        recvTlpCntReg <= recvTlpCnt;
        recvBytesReg <= recvBytesCnt;
        reshapeMrrs.streamFifoIn.enq(stream);
    endrule

    // rule log;
    //     let stream = dwRemove.streamFifoOut.first;
    //     $display("dwRemove output stream", fshow(stream));
    // endrule
    // Pipeline stage 1: split to req to MRRS chunks
    rule reqSplit;
        let req = reqInFifo.first;
        reqInFifo.deq;
        let exReq = DmaExtendRequest {
            startAddr : req.startAddr,
            endAddr   : req.startAddr + req.length - 1,
            length    : req.length,
            tag       : 0
        };
        chunkSplitor.dmaRequestFifoIn.enq(exReq);
    endrule

    // Pipeline stage 2: generate read descriptor
    rule cqDescGen;
        let req = chunkSplitor.chunkRequestFifoOut.first;
        chunkSplitor.chunkRequestFifoOut.deq;
        let token <- cBuffer.reserve.get;
        let exReq = DmaExtendRequest {
                startAddr:  req.startAddr,
                endAddr  :  req.startAddr + req.length - 1,
                length   :  req.length,
                tag      :  zeroExtend(token) | (zeroExtend(pathIdx) << (valueOf(DES_NONEXTENDED_TAG_WIDTH)-1))
            };
        rqDescGenerator.exReqFifoIn.enq(exReq);
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: tx a new read chunk, tag:%d, addr:%d, length:%d",  exReq.tag, req.startAddr, req.length);
    endrule

    // Pipeline stage 3: generate Tlp to PCIe Adapter
    rule tlpGen;
        let stream = rqDescGenerator.descFifoOut.first;
        let sideBandByteEn = rqDescGenerator.byteEnFifoOut.first;
        rqDescGenerator.descFifoOut.deq;
        rqDescGenerator.byteEnFifoOut.deq;
        stream.isFirst = True;
        stream.isLast  = True;
        tlpOutFifo.enq(stream);
        tlpByteEnFifo.enq(sideBandByteEn);
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: output new tlp, BE:%h/%h", tpl_1(sideBandByteEn), tpl_2(sideBandByteEn));
    endrule

    // User Logic Ifc
    interface rdReqFifoIn = convertFifoToFifoIn(reqInFifo);
    interface dataFifoOut = reshapeMrrs.streamFifoOut;
    // PCIe IP Ifc
    interface tlpFifoIn   = convertFifoToFifoIn(tlpInFifo);
    interface tlpFifoOut  = convertFifoToFifoOut(tlpOutFifo);
    interface tlpSideBandFifoOut = convertFifoToFifoOut(tlpByteEnFifo);
endmodule

// Core path of a single stream, from (DataStream, DmaRequest) ==> (DataStream, SideBandByteEn)
// split to chunks, align to DWord and add descriptor at the first
interface C2HWriteCore;
    // User Logic Ifc
    interface FifoIn#(DataStream)      dataFifoIn;
    interface FifoIn#(DmaRequest)      wrReqFifoIn;
    // PCIe IP Ifc
    interface FifoOut#(DataStream)     tlpFifoOut;
    interface FifoOut#(SideBandByteEn) tlpSideBandFifoOut;
endinterface

// Total Latency: 1 + 3 + 2 + 1 = 7
module mkC2HWriteCore(C2HWriteCore);
    FIFOF#(DataStream)     dataInFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)     wrReqInFifo <- mkFIFOF;
    FIFOF#(DataStream)     dataOutFifo <- mkFIFOF;
    FIFOF#(SideBandByteEn) byteEnOutFifo <- mkFIFOF;

    Reg#(Tag)  tagReg <- mkReg(0);

    ChunkSplit chunkSplit <- mkChunkSplit(DMA_TX);
    StreamShiftAlignToDw streamAlign <- mkStreamShiftAlignToDw(fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH))));
    RqDescriptorGenerator rqDescGenerator <- mkRqDescriptorGenerator(True);

    // Pipeline stage 1: split the whole write request to chunks, latency = 3
    rule splitToChunks;
        let wrStream = dataInFifo.first;
        // if (wrStream.isLast || wrStream.isFirst) begin $display($time, "ns SIM INFO @ mkC2HWriteCore: ", fshow(wrStream)); end
        if (wrStream.isFirst && wrReqInFifo.notEmpty) begin
            wrReqInFifo.deq;
            let wrReq = wrReqInFifo.first;
            let exReq = DmaExtendRequest {
                startAddr : wrReq.startAddr,
                endAddr   : wrReq.startAddr + wrReq.length - 1,
                length    : wrReq.length,
                tag       : 0
            };
            chunkSplit.reqFifoIn.enq(exReq);
            dataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrStream);
        end
        else if (!wrStream.isFirst) begin
            dataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrStream);
        end
    endrule

    // Pipeline stage 2: shift the datastream for descriptor adding and dw alignment
    rule shiftToAlignment;
        if (chunkSplit.chunkReqFifoOut.notEmpty) begin
            let chunkReq = chunkSplit.chunkReqFifoOut.first;
            chunkSplit.chunkReqFifoOut.deq;
            let exReq = DmaExtendRequest {
                startAddr:  chunkReq.startAddr,
                endAddr  :  chunkReq.startAddr + chunkReq.length - 1,
                length   :  chunkReq.length,
                tag      :  tagReg
            };
            tagReg <= tagReg + 1;
            let startAddrOffset = byteModDWord(exReq.startAddr);
            streamAlign.setAlignMode(unpack(startAddrOffset));
            rqDescGenerator.exReqFifoIn.enq(exReq);
            $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: tx a new write chunk, tag:%d, addr:%d, length:%d",  tagReg, chunkReq.startAddr, chunkReq.length);
        end
        if (chunkSplit.chunkDataFifoOut.notEmpty) begin
            let chunkDataStream = chunkSplit.chunkDataFifoOut.first;
            chunkSplit.chunkDataFifoOut.deq;
            streamAlign.dataFifoIn.enq(chunkDataStream);
            if (chunkDataStream.isLast && chunkDataStream.isFirst) begin
                $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: tx write chunk end  , tag:%d", tagReg);
            end
            else if (chunkDataStream.isLast) begin
                $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: tx write chunk end  , tag:%d", tagReg - 1);
            end
        end
    endrule

    // Pipeline stage 3: Add descriptor and add to the axis convert module
    rule addDescriptorToAxis;
        let stream = streamAlign.dataFifoOut.first;
        streamAlign.dataFifoOut.deq;
        if (stream.isFirst) begin
            let descStream = rqDescGenerator.descFifoOut.first;
            let sideBandByteEn = rqDescGenerator.byteEnFifoOut.first;
            rqDescGenerator.descFifoOut.deq;
            rqDescGenerator.byteEnFifoOut.deq;
            stream.data = stream.data | descStream.data;
            stream.byteEn = stream.byteEn | descStream.byteEn;
            byteEnOutFifo.enq(sideBandByteEn);
            $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: tx a new tlp, BE:%b/%b", tpl_1(sideBandByteEn), tpl_2(sideBandByteEn));
        end
        dataOutFifo.enq(stream);
        // $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: tlp stream", fshow(stream));
    endrule

    interface dataFifoIn         = convertFifoToFifoIn(dataInFifo);
    interface wrReqFifoIn        = convertFifoToFifoIn(wrReqInFifo);
    interface tlpFifoOut         = convertFifoToFifoOut(dataOutFifo);
    interface tlpSideBandFifoOut = convertFifoToFifoOut(byteEnOutFifo);
endmodule
