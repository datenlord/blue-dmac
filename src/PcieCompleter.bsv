import FIFO::*;

import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef 1   IDEA_DWORD_CNT_OF_CSR;
typedef 10  CMPL_NPREQ_INFLIGHT_NUM;
typedef 20  CMPL_NPREQ_WAITING_CLKS;

typedef struct {
    DmaCsrAddr  addr;
    DmaCsrValue value;
} CsrWriteReq deriving(Bits, Eq, Bounded, FShow);

typedef DmaCsrValue CsrReadResp;

typedef struct {
    DmaCsrAddr rdAddr;
    PcieCompleterRequestNonPostedStore npInfo;
} CsrReadReq deriving(Bits, Eq, Bounded, FShow);

interface Completer;
    interface RawPcieCompleterRequest  rawCompleterRequest;
    interface RawPcieCompleterComplete rawCompleterComplete;
    interface DmaHostToCardWrite       h2cCsrWrite;
    interface DmaHostToCardRead        h2cCsrRead;
    method DmaCsrValue getRegisterValue(DmaCsrAddr addr);
endinterface

interface CompleterRequest;
    interface FifoIn#(PcieAxiStream) axiStreamFifoIn;
    interface FifoOut#(CsrWriteReq)  csrWriteReqFifoOut;
    interface FifoOut#(CsrReadReq)   csrReadReqFifoOut;
endinterface

interface CompleterComplete;
    interface FifoOut#(PcieAxiStream) axiStreamFifoOut;
    interface FifoIn#(CsrReadResp)    csrReadRespFifoIn;
    interface FifoIn#(CsrReadReq)     csrReadReqFifoIn;
endinterface

// PcieCompleter does not support straddle mode now
// The completer is designed only for CSR Rd/Wr, and will ignore any len>32bit requests 
(* synthesize *)
module mkCompleterRequest(CompleterRequest);
    FIFOF#(PcieAxiStream)   inFifo    <- mkFIFOF;
    FIFOF#(CsrWriteReq)     wrReqFifo <- mkFIFOF;
    FIFOF#(CsrReadReq)      rdReqFifo <- mkFIFOF;

    Reg#(Bool) isInPacket <- mkReg(False);
    Reg#(Uint#(32)) illegalPcieReqCntReg <- mkReg(0);

    function PcieCompleterRequestDescriptor getDescriptorFromFirstBeat(PcieAxiStream axiStream);
        return pack(axiStream.tDATA[valueOf(CQ_DESCRIPTOR_WIDTH)-1:0]);
    endfunction

    function Data getDataFromFirstBeat(PcieAxiStream axiStream);
        return axiStream.tData >> valueOf(CQ_DESCRIPTOR_WIDTH);
    endfunction

    function Bool isFirstBytesAllValid(PcieCompleterCompleteSideBandFrame sideBand);
        return (sideBand.firstByteEn[valueOf(PCIE_TLP_FIRST_BE_WIDTH)-1] == 1);
    endfunction

    function DmaCsrAddr getAddrFromCqDescriptor(PcieCompleterRequestDescriptor descriptor);
        let addr = getAddrLowBits(zeroExtend(descriptor.address), descriptor.barAperture);
        // Only support one BAR now, no operation
        if (descriptor.barId == 0) begin
            addr = addr;
        end
        else begin
            addr = 0;
        end
        return truncate(addr);
    endfunction

    function PcieCompleterRequestNonPostedStore convertDescriptorToNpStore(PcieCompleterRequestDescriptor descriptor);
        return PcieCompleterRequestNonPostedStore {
            attributes  : descriptor.attributes,
            trafficClass: descriptor.trafficClass,
            tag         : descriptor.tag,
            requesterId : descriptor.requesterId
        };
    endfunction

    rule parseData;
        inFifo.deq;
        let axiStream = inFifo.first;
        PcieCompleterRequestSideBandFrame sideBand = pack(axiStream.tUser);
        isInPacket <= !axiStream.isLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(axiStream);
            case (descriptor.reqType) begin
                MEM_WRITE_REQ: begin
                    if (descriptor.dwordCnt == valueOf(IDEA_DWORD_CNT_OF_CSR) && isFirstBytesAllValid) begin
                        DmaCsrValue wrValue = getDataFromFirstBeat(axiStream)[valueOf(DMA_CSR_ADDR_WIDTH)-1:0];
                        DmaCsrAddr wrAddr = getAddrFromCqDescriptor(descriptor);
                        let wrReq = CsrWriteReq {
                            address : wrAddr,
                            value   : wrValue
                        }
                        wrReqFifo.enq(wrReq);
                    end
                    else begin
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                MEM_READ_REQ: begin
                    let rdReqAddr = getAddrFromCqDescriptor(descriptor);
                    let npInfo = convertDescriptorToNpStore(descriptor);
                    let rdReq = CsrReadReq{
                        rdAddr: rdReqAddr,
                        npInfo: npInfo
                    }
                    rdReqFifo.enq(rdReq);
                end
                default: illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
            end
        end
        outFifo.enq(stream);
    endrule

    interface axiStreamFifoIn    = convertFifoToFifoIn(inFifo);
    interface csrWriteReqFifoOut = convertFifoToFifoOut(wrReqFifo);
    interface csrReadReqFifoOut  = convertFifoToFifoOut(rdReqFifo);
endmodule

(* synthesize *)
module mkCompleterComplete(CompleterComplete);
    FIFOF#(PcieAxiStream) outFifo    <- mkFIFOF;
    FIFOF#(CsrReadResp)   rdRespFifo <- mkFIFOF;
    FIFOF#(CsrReadReq)    rdReqFifo  <- mkFIFOF;

    // TODO: the logic of cc

    interface axiStreamFifoOut   = convertFifoToFifoOut(outFifo);
    interface csrReadRespFifoIn  = convertFifoToFifoIn(rdRespFifo);
    interface csrWriteReqFifoOut = convertFifoToFifoIn(rdReqFifo);
endmodule

(* synthesize *)
module mkCompleter(Completer);
    CompleterRequest  cmplRequest  = mkCompleterRequest;
    CompleterComplete cmplComplete = mkCompleterComplete;

    FIFOF#(csrReadResp) csrRdRespFifo      <- mkFIFOF;
    FIFOF#(csrReadReq) csrRdReqOutFifo     <- mkFIFOF;
    FIFOF#(csrReadReq) csrRdReqWaitingFifo <- mkSizedFIFOF(CMPL_NPREQ_INFLIGHT_NUM);

    Reg#(PcieNonPostedRequstCount) npReqCreditCntReg <- mkReg(0);

    interface RawPcieCompleterRequest;
        interface rawAxiStreamSlave = mkFifoInToRawPcieAxiStreamSlave#(cmplRequest.axiStreamFifoIn);
        // TODO: back-pressure according to the temperory stored RdReq Num
        method PcieNonPostedRequst nonPostedReqCreditIncrement = 2'b11;
        method Action nonPostedReqCreditCnt(PcieNonPostedRequstCount nonPostedpReqCount);
            npReqCreditCntReg <= nonPostedpReqCount;
        endmethod
    endinterface

    interface RawPcieCompleterComplete;
        interface rawAxiStreamSlave = mkFifoOutToRawPcieAxiStreamMaster#(cmplComplete.axiStreamFifoOut);
    endinterface

    interface csrWriteReqFifoOut = cmplRequest.csrWriteReqFifoOut;

    interface csrReadReqFifoOut  = convertFifoToFifoOut(csrRdReqOutFifo);
    interface csrReadRespFifoIn  = convertFifoToFifoIn(csrRdRespFifo);

    // TODO: get internal registers value
    method DmaCsrValue getRegisterValue(DmaCsrAddr addr);
        return 0;
    method

endmodule
