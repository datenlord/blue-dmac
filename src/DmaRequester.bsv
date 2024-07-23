import FIFOF::*;

import SemiFifo::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

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

    // TODO: RQ Logic

    interface wrDataFifoIn = convertFifoToFifoIn(wrDataInFifo);
    interface wrReqFifoIn  = convertFifoToFifoIn(wrReqInFifo);
    interface rdReqFifoIn  = convertFifoToFifoIn(rdReqInFifo);
    interface axiStreamFifoOut = convertFifoToFifoOut(axiStreamOutFifo);
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
