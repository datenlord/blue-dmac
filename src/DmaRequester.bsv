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
    StreamConcat streamConcat <- mkStreamConcat;

    FIFOF#(DataStream) wrDataInFifo <- mkFIFOF;
    FIFOF#(DmaRequest) wrReqInFifo  <- mkFIFOF;
    FIFOF#(DmaRequest) rdReqInFifo  <- mkFIFOF;
    FIFOF#(ReqReqAxiStream) axiStreamOutFifo <- mkFIFOF;

    Reg#(DmaMemAddr) inflightRemainBytesReg <- mkReg(0);
    Reg#(Bool)  isInWritingReg  <- mkReg(False);
    Wire#(Bool) postedEnWire    <- mkDWire(False);
    Wire#(Bool) nonPostedEnWire <- mkDWire(True);

    function DataStream genRQDescriptorStream(DmaRequest req, Bool isWrite);
        let descriptor = PcieRequesterRequestDescriptor {
            forceECRC       : False,
            attributes      : 0,
            trafficClass    : 0,
            requesterIdEn   : False,
            completerId     : 0,
            tag             : 0,
            requesterId     : 0,
            isPoisoned      : False,
            reqType         : isWrite ? fromInteger(valueOf(MEM_WRITE_REQ)) : fromInteger(valueOf(MEM_READ_REQ)),
            dwordCnt        : truncate(req.length >> 2 + (req.length[0] | req.length[1])),
            address         : truncate(req.startAddr >> 2),
            addrType        : 2'b10
        };
        ByteEn byteEn = 1;
        let stream = DataStream {
            data    : zeroExtend(pack(descriptor)),
            byteEn  : (byteEn << (valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH)) + 1)) - 1,
            isFirst : True,
            isLast  : False
        };
        return stream;
    endfunction

    // TODO: RQ Logic
    rule recvWriteReq if (postedEnWire);
        if (!isInWritingReg) begin
            let wrReq  = wrReqInFifo.first;
            let wrData = wrDataInFifo.first;
            wrReqInFifo.deq;
            wrDataInFifo.deq;
            isInWritingReg <= (wrReq.length > fromInteger(valueOf(ONE_TLP_THRESH)));
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
