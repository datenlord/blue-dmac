import FIFOF::*;
import GetPut::*;
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
        $display($time, "ns SIM INFO @ mkDmaC2HPipe%d: New Request isWrite:%b startAddr:%h length:%d",
                pathIdx, pack(req.isWrite), req.startAddr, req.length);
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

module mkC2HReadCore#(DmaPathNo pathIdx)(C2HReadCore);
    FIFOF#(StraddleStream) tlpInFifo      <- mkFIFOF;
    FIFOF#(DmaRequest)     reqInFifo      <- mkFIFOF;
    FIFOF#(DataStream)     tlpOutFifo     <- mkFIFOF;
    FIFOF#(SideBandByteEn) tlpByteEnFifo  <- mkFIFOF;

    FIFOF#(SlotToken)      tagFifo        <- mkSizedFIFOF(valueOf(TAdd#(1, STREAM_HEADER_REMOVE_LATENCY)));      
    FIFOF#(Bool)           completedFifo  <- mkSizedFIFOF(valueOf(TAdd#(1, STREAM_HEADER_REMOVE_LATENCY)));      

    StreamPipe     descRemove     <- mkStreamHeaderRemove(fromInteger(valueOf(TDiv#(DES_RC_DESCRIPTOR_WIDTH, BYTE_WIDTH)))); 
    StreamPipe     streamReshape  <- mkStreamReshape;
    ChunkCompute   chunkSplitor   <- mkChunkComputer(DMA_RX);
    CompletionFifo#(SLOT_PER_PATH, DataStream)  cBuffer <- mkCompletionFifo(valueOf(MAX_STREAM_NUM_PER_COMPLETION));
    
    Reg#(Bool) hasReadOnce <- mkReg(False);

    // Pipeline stage 1: convert StraddleStream to DataStream, may cost 2 cycle for one StraddleStream
    rule convertStraddleToDataStream;
        let sdStream = tlpInFifo.first;
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: recv new stream from straddle adapter, isDouble:%b", pack(sdStream.isDoubleFrame));
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
        descRemove.streamFifoIn.enq(stream);
        tagFifo.enq(tag);
        completedFifo.enq(isCompleted);
        $display("parse from straddle", fshow(stream));
    endrule

    // Pipeline stage 2: remove the descriptor in the head of each TLP

    // Pipeline stage 3: Buffer the received DataStreams and reorder the,
    rule reorderStream;
        let stream = descRemove.streamFifoOut.first;
        let isCompleted = completedFifo.first;
        let tag = tagFifo.first;
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: recv new tlp tag%d, isCompleted:%b", tag, pack(isCompleted));
        $display("desc remove output", fshow(stream));
        descRemove.streamFifoOut.deq;
        completedFifo.deq;
        tagFifo.deq;
        stream.isLast = isCompleted && stream.isLast;
        cBuffer.append.enq(tuple2(tag, stream));
        if (stream.isLast) begin
            cBuffer.complete.put(tag);
        end
    endrule

    // Pipeline stage 4: there may be bubbles in the first and last DataStream of a TLP because of RCB
    //  Reshape the DataStream and make sure it is continuous
    rule reshapeStream;
        let stream = cBuffer.drain.first;
        cBuffer.drain.deq;
        streamReshape.streamFifoIn.enq(stream);
        $display("cbuf output", fshow(stream));
    endrule

    // Pipeline stage 1: split to req to MRRS chunks
    rule reqSplit;
        let req = reqInFifo.first;
        reqInFifo.deq;
        chunkSplitor.dmaRequestFifoIn.enq(req);
    endrule

    // Pipeline stage 2: generate read descriptor
    rule cqDescGen;
        let req = chunkSplitor.chunkRequestFifoOut.first;
        chunkSplitor.chunkRequestFifoOut.deq;
        let token <- cBuffer.reserve.get;
        let descriptor  = PcieRequesterRequestDescriptor {
            forceECRC       : False,
            attributes      : 0,
            trafficClass    : 0,
            requesterIdEn   : False,
            completerId     : 0,
            tag             : zeroExtend(token) | (zeroExtend(pathIdx) << (valueOf(DES_NONEXTENDED_TAG_WIDTH)-1)),
            requesterId     : 0,
            isPoisoned      : False,
            reqType         : fromInteger(valueOf(MEM_READ_REQ)),
            dwordCnt        : truncate(req.length >> valueOf(BYTE_DWORD_SHIFT_WIDTH)) + zeroExtend(req.length[0]|req.length[1]),
            address         : truncate(req.startAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)),
            addrType        : fromInteger(valueOf(TRANSLATED_ADDR))
        };
        let stream = DataStream {
            data    : zeroExtend(pack(descriptor)),
            byteEn  : convertBytePtr2ByteEn(fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH)))),
            isFirst : True,
            isLast  : True
        };
        tlpOutFifo.enq(stream);
        let endAddr = req.startAddr + req.length;
        ByteModDWord startAddrOffset = byteModDWord(req.startAddr);
        ByteModDWord endAddrOffset = byteModDWord(endAddr);
        let firstByteEn = convertDWordOffset2FirstByteEn(startAddrOffset);
        let lastByteEn  = convertDWordOffset2LastByteEn(endAddrOffset);
        tlpByteEnFifo.enq(tuple2(firstByteEn, lastByteEn));
        $display($time, "ns SIM INFO @ mkDmaC2HReadCore: output new tlp, BE:%h/%h", firstByteEn, lastByteEn);
    endrule

    // User Logic Ifc
    interface rdReqFifoIn = convertFifoToFifoIn(reqInFifo);
    interface dataFifoOut = streamReshape.streamFifoOut;
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

module mkC2HWriteCore(C2HWriteCore);
    FIFOF#(DataStream)     dataInFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)     wrReqInFifo <- mkFIFOF;
    FIFOF#(DataStream)     dataOutFifo <- mkFIFOF;
    FIFOF#(SideBandByteEn) byteEnOutFifo <- mkFIFOF;

    ChunkSplit chunkSplit <- mkChunkSplit(DMA_TX);
    StreamShiftAlignToDw streamAlign <- mkStreamShiftAlignToDw(fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH))));
    RqDescriptorGenerator rqDescGenerator <- mkRqDescriptorGenerator(True);

    // Pipeline stage 1: split the whole write request to chunks, latency = 3
    rule splitToChunks;
        let wrStream = dataInFifo.first;
        $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: get new writing stream");
        if (wrStream.isFirst && wrReqInFifo.notEmpty) begin
            wrReqInFifo.deq;
            chunkSplit.reqFifoIn.enq(wrReqInFifo.first);
            dataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrStream);
            $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: new write start, startAddr:%h, length:%d ", wrReqInFifo.first.startAddr, wrReqInFifo.first.length);
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
            let endAddr = chunkReq.startAddr + chunkReq.length;
            let exReq = DmaExtendRequest {
                startAddr:  chunkReq.startAddr,
                endAddr  :  endAddr,
                length   :  chunkReq.length
            };
            streamAlign.reqFifoIn.enq(exReq);
            rqDescGenerator.exReqFifoIn.enq(exReq);
        end
        if (chunkSplit.chunkDataFifoOut.notEmpty) begin
            let chunkDataStream = chunkSplit.chunkDataFifoOut.first;
            chunkSplit.chunkDataFifoOut.deq;
            streamAlign.dataFifoIn.enq(chunkDataStream);
        end
    endrule

    // Pipeline stage 3: Add descriptor and add to the axis convert module
    rule addDescriptorToAxis;
        if (streamAlign.byteEnFifoOut.notEmpty) begin
            let sideBandByteEn = streamAlign.byteEnFifoOut.first;
            streamAlign.byteEnFifoOut.deq;
            byteEnOutFifo.enq(sideBandByteEn);
            $display($time, "ns SIM INFO @ mkDmaC2HWriteCore: output new tlp, BE:%h/%h", tpl_1(sideBandByteEn), tpl_2(sideBandByteEn));
        end
        if (streamAlign.dataFifoOut.notEmpty) begin
            let stream = streamAlign.dataFifoOut.first;
            streamAlign.dataFifoOut.deq;
            if (stream.isFirst) begin
                let descStream = rqDescGenerator.descFifoOut.first;
                rqDescGenerator.descFifoOut.deq;
                stream.data = stream.data | descStream.data;
                stream.byteEn = stream.byteEn | descStream.byteEn;
            end
            dataOutFifo.enq(stream);
        end
    endrule

    interface dataFifoIn         = convertFifoToFifoIn(dataInFifo);
    interface wrReqFifoIn        = convertFifoToFifoIn(wrReqInFifo);
    interface tlpFifoOut         = convertFifoToFifoOut(dataOutFifo);
    interface tlpSideBandFifoOut = convertFifoToFifoOut(byteEnOutFifo);
endmodule
