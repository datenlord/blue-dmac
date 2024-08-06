import FIFOF::*;
import GetPut::*;

import SemiFifo::*;
import StreamUtils::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import ReqRequestCore::*;
import DmaTypes::*;

typedef TSub#(DATA_WIDTH, DES_RQ_DESCRIPTOR_WIDTH) ONE_TLP_THRESH;

interface DmaRequester;
    interface DmaCardToHostWrite        c2hWrite;
    interface DmaCardToHostRead         c2hRead;
    (* prefix = "" *) interface RawPcieRequesterRequest   rawRequesterRequest;
    (* prefix = "" *) interface RawPcieRequesterComplete  rawRequesterComplete;
endinterface

typedef 2 STRADDLE_NUM;

interface DmaRequesterRequestFifoIn;
    interface FifoIn#(DataStream) wrDataFifoIn;
    interface FifoIn#(DmaRequest) wrReqFifoIn;
    interface FifoIn#(DmaRequest) rdReqFifoIn;
endinterface

interface RequesterRequest;
    interface DmaRequesterRequestFifoIn reqA;
    interface DmaRequesterRequestFifoIn reqB;
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
    RequesterRequestCore rqACore <- mkRequesterRequestCore;
    RequesterRequestCore rqBCore <- mkRequesterRequestCore;
    FIFOF#(ReqReqAxiStream) axiStreamOutFifo <- mkFIFOF;
    
    Reg#(DmaMemAddr) inflightRemainBytesReg <- mkReg(0);
    Reg#(Bool)  isInWritingReg  <- mkReg(False);
    Wire#(Bool) postedEnWire    <- mkDWire(True);
    Wire#(Bool) nonPostedEnWire <- mkDWire(True);

    ConvertDataStreamsToStraddleAxis straddleAxis <- mkConvertDataStreamsToStraddleAxis;

    // Pipeline stage 1: split to chunks, align to DWord and add descriptor at the first
    // See RequesterRequestCore

    // Pipeline stage 2: put 2 core output datastream to straddleAxis and generate ReqReqAxiStream
    rule coreToStraddle;
        if (rqACore.dataFifoOut.notEmpty) begin
            let stream = rqACore.dataFifoOut.first;
            if (stream.isFirst && rqACore.byteEnFifoOut.notEmpty) begin
                let sideBandByteEn = rqACore.byteEnFifoOut.first;
                straddleAxis.byteEnAFifoIn.enq(sideBandByteEn);
                rqACore.dataFifoOut.deq;
                straddleAxis.dataAFifoIn.enq(stream);
            end
            else begin
                rqACore.dataFifoOut.deq;
                straddleAxis.dataAFifoIn.enq(stream);
            end
        end
        if (rqBCore.dataFifoOut.notEmpty) begin
            let stream = rqBCore.dataFifoOut.first;
            if (stream.isFirst && rqBCore.byteEnFifoOut.notEmpty) begin
                let sideBandByteEn = rqBCore.byteEnFifoOut.first;
                straddleAxis.byteEnBFifoIn.enq(sideBandByteEn);
                rqBCore.dataFifoOut.deq;
                straddleAxis.dataBFifoIn.enq(stream);
            end
            else begin
                rqBCore.dataFifoOut.deq;
                straddleAxis.dataBFifoIn.enq(stream);
            end
        end
    endrule

    interface DmaRequesterRequestFifoIn reqA;
        interface wrDataFifoIn = rqACore.dataFifoIn;
        interface wrReqFifoIn  = rqACore.wrReqFifoIn;
        interface rdReqFifoIn  = rqACore.rdReqFifoIn;
    endinterface

    interface DmaRequesterRequestFifoIn reqB;
        interface wrDataFifoIn = rqBCore.dataFifoIn;
        interface wrReqFifoIn  = rqBCore.wrReqFifoIn;
        interface rdReqFifoIn  = rqBCore.rdReqFifoIn;
    endinterface

    interface axiStreamFifoOut = straddleAxis.axiStreamFifoOut;

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
