import FIFOF::*;
import GetPut::*;

import SemiFifo::*;
import StreamUtils::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef TSub#(DATA_WIDTH, DES_RQ_DESCRIPTOR_WIDTH) ONE_TLP_THRESH;

typedef PcieAxiStream#(PCIE_REQUESTER_REQUEST_TUSER_WIDTH)  ReqReqAxiStream;
typedef PcieAxiStream#(PCIE_REQUESTER_COMPLETE_TUSER_WIDTH) ReqCmplAxiStream;

interface DmaRequester;
    interface DmaCardToHostWrite        c2hWrite;
    interface DmaCardToHostRead         c2hRead;
    (* prefix = "" *) interface RawPcieRequesterRequest   rawRequesterRequest;
    (* prefix = "" *) interface RawPcieRequesterComplete  rawRequesterComplete;
endinterface

interface RequesterRequest;
    interface FifoIn#(DataStream) wrDataFifoIn;
    interface FifoIn#(DmaRequest) wrReqFifoIn;
    interface FifoIn#(DmaRequest) rdReqFifoIn;
    interface FifoOut#(ReqReqAxiStream) axiStreamFifoOut;
    interface Put#(Bool) postedEn;
    interface Put#(Bool) nonPostedEn;
    interface Get#(Bool) isWriteDataRecvDone;
endinterface

interface RequesterComplete;
    interface FifoIn#(DmaRequest)  rdReqFifoIn;
    interface FifoOut#(DataStream) rdDataFifoOut;
    interface FifoIn#(ReqCmplAxiStream) axiStreamFifoIn;
endinterface

module mkRequesterRequest(RequesterRequest);
    FIFOF#(DataStream) wrDataInFifo <- mkFIFOF;
    FIFOF#(DmaRequest) wrReqInFifo  <- mkFIFOF;
    FIFOF#(DmaRequest) rdReqInFifo  <- mkFIFOF;
    FIFOF#(ReqReqAxiStream) axiStreamOutFifo <- mkFIFOF;

    Reg#(DmaMemAddr) inflightRemainBytesReg <- mkReg(0);
    Reg#(Bool)  isInWritingReg  <- mkReg(False);
    Wire#(Bool) postedEnWire    <- mkDWire(False);
    Wire#(Bool) nonPostedEnWire <- mkDWire(True);

    ChunkSplit chunkSplit <- mkChunkSplit;
    AlignedDescGen rqDescGenarator <- mkAlignedRqDescGen;

    // Pipeline stage 1: split the whole write request to chunks, latency = 3
    rule recvWriting if (postedEnWire);
        if (wrReqInFifo.notEmpty && chunkSplit.dataFifoIn.notFull) begin
            wrReqInFifo.deq;
            chunkSplit.reqFifoIn.enq(wrReqInFifo.first);
        end
        if (wrDataInFifo.notEmpty && chunkSplit.reqFifoIn.notFull) begin
            wrDataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrDataInFifo.first);
        end
    endrule

    // Pipeline stage 2: generate the RQ descriptor, which may be with 0~3 Byte invalid data for DW alignment, latency = 2
    rule addDescriptor;
        if (chunkSplit.chunkReqFifoOut.notEmpty) begin
            let chunkReq = chunkSplit.chunkReqFifoOut.first;
            chunkSplit.chunkReqFifoOut.deq;
            rqDescGenarator.reqFifoIn.enq(chunkReq);
        end
        if (chunkSplit.chunkDataFifoOut.notEmpty) begin
            let chunkDataStream = chunkSplit.chunkDataFifoOut.first;
            chunkSplit.chunkDataFifoOut.deq;
            descriptorConcat.inputStreamSecondFifoIn.enq(chunkDataStream);
        end
    endrule

    interface wrDataFifoIn = convertFifoToFifoIn(wrDataInFifo);
    interface wrReqFifoIn  = convertFifoToFifoIn(wrReqInFifo);
    interface rdReqFifoIn  = convertFifoToFifoIn(rdReqInFifo);
    interface axiStreamFifoOut = convertFifoToFifoOut(axiStreamOutFifo);

    interface Put postedEn;
        method Action put(Bool postedEnable);
            postedEnWire <= postedEnable;
        endmethod
    endinterface
    
    interface Put nonPostedEn;
        method Action put(Bool nonPostedEnable);
            nonPostedEnWire <= nonPostedEnable;
        endmethod
    endinterface

    interface Get isWriteDataRecvDone;
        method ActionValue#(Bool) get();
            return (inflightRemainBytesReg == 0);
        endmethod
    endinterface
endmodule

module mkRequesterComplete(RequesterComplete);
    FIFOF#(DataStream) rdDataOutFifo <- mkFIFOF;
    FIFOF#(DmaRequest) rdReqInFifo   <- mkFIFOF;
    FIFOF#(ReqCmplAxiStream) axiStreamInFifo <- mkFIFOF;

    // TODO: RC Logic

    interface rdReqFifoIn   = convertFifoToFifoIn(rdReqInFifo);
    interface rdDataFifoOut = convertFifoToFifoOut(rdDataOutFifo);
    interface axiStreamFifoIn = convertFifoToFifoIn(axiStreamInFifo);
endmodule

(* synthesize *)
module mkDmaRequester(DmaRequester);
    RequesterRequest  reqRequest  <- mkRequesterRequest;
    RequesterComplete reqComplete <- mkRequesterComplete;

    FIFOF#(DataStream) c2hWriteDataFifo <- mkFIFOF;
    FIFOF#(DmaRequest) c2hWriteReqFifo  <- mkFIFOF;
    FIFOF#(DataStream) c2hReadDataFifo  <- mkFIFOF;
    FIFOF#(DmaRequest) c2hReadReqFifo   <- mkFIFOF;

    let rawAxiStreamSlaveIfc  <- mkFifoInToRawPcieAxiStreamSlave(reqComplete.axiStreamFifoIn);
    let rawAxiStreamMasterIfc <- mkFifoOutToRawPcieAxiStreamMaster(reqRequest.axiStreamFifoOut);

    interface DmaCardToHostWrite c2hWrite;
        interface dataFifoIn = convertFifoToFifoIn(c2hWriteDataFifo);
        interface reqFifoIn  = convertFifoToFifoIn(c2hWriteReqFifo);
        // TODO: isDone need assertion
        method Bool isDone = True;
    endinterface

    interface DmaCardToHostRead c2hRead;
        interface reqFifoIn  = convertFifoToFifoIn(c2hReadReqFifo);
        interface dataFifoOut  = convertFifoToFifoOut(c2hReadDataFifo);
    endinterface

    interface RawPcieRequesterRequest rawRequesterRequest;
        interface rawAxiStreamMaster = rawAxiStreamMasterIfc;
        method Action pcieProgressTrack(
            Bool            tagValid0,
            Bool            tagValid1,
            PcieRqTag       tag0,
            PcieRqTag       tag1,
            Bool            seqNumValid0,
            Bool            seqNumValid1,
            PcieRqSeqNum    seqNum0,
            PcieRqSeqNum    seqNum1
            );
            // Not support progress track now
        endmethod
    endinterface

    interface RawPcieRequesterComplete rawRequesterComplete;
        interface rawAxiStreamSlave = rawAxiStreamSlaveIfc;
    endinterface

endmodule
