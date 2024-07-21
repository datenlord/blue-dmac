import FIFO::*;

import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef 1   IDEA_DWORD_CNT_OF_CSR;
typedef 64  CMPL_NPREQ_INFLIGHT_NUM;
typedef 20  CMPL_NPREQ_WAITING_CLKS;
typedef 2'b11 NP_CREDIT_INCREMENT;
typedef 2'b00 NP_CREDIT_NOCHANGE;

typedef struct {
    DmaCsrAddr  addr;
    DmaCsrValue value;
} CsrWriteReq deriving(Bits, Eq, Bounded, FShow);

typedef DmaCsrValue CsrReadResp;

typedef struct {
    DmaCsrAddr rdAddr;
    PcieCompleterRequestDescriptor npInfo;
} CsrReadReq deriving(Bits, Eq, Bounded, FShow);

interface DmaCompleter;
    interface RawPcieCompleterRequest  rawCompleterRequest;
    interface RawPcieCompleterComplete rawCompleterComplete;
    interface DmaHostToCardWrite       h2cWrite;
    interface DmaHostToCardRead        h2cRead;
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

    function DmaCsrAddr getCsrAddrFromCqDescriptor(PcieCompleterRequestDescriptor descriptor);
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

    rule parse;
        inFifo.deq;
        let axiStream = inFifo.first;
        PcieCompleterRequestSideBandFrame sideBand = pack(axiStream.tUser);
        isInPacket <= !axiStream.isLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(axiStream);
            case (descriptor.reqType) begin
                MEM_WRITE_REQ: begin
                    if (descriptor.dwordCnt == valueOf(IDEA_DWORD_CNT_OF_CSR) && isFirstBytesAllValid) begin
                        let firstData = getDataFromFirstBeat(axiStream);
                        DmaCsrValue wrValue = firstData[valueOf(DMA_CSR_ADDR_WIDTH)-1:0];
                        DmaCsrAddr wrAddr = getCsrAddrFromCqDescriptor(descriptor);
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
                    let rdReqAddr = getCsrAddrFromCqDescriptor(descriptor);
                    let rdReq = CsrReadReq{
                        rdAddr: rdReqAddr,
                        npInfo: descriptor
                    }
                    rdReqFifo.enq(rdReq);
                end
                default: illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
            end
        end
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
    interface csrReadReqFifoOut  = convertFifoToFifoIn(rdReqFifo);
endmodule

(* synthesize *)
module mkDmaCompleter(DmaCompleter);
    CompleterRequest  cmplRequest  = mkCompleterRequest;
    CompleterComplete cmplComplete = mkCompleterComplete;

    FIFOF#(DmaCsrValue) h2cCsrWriteDataFifo <- mkFIFOF;
    FIFOF#(DmaCsrAddr)  h2cCsrWriteReqFifo  <- mkFIFOF;
    FIFOF#(DmaCsrAddr)  h2cCsrReadReqFifo   <- mkFIFOF;
    FIFOF#(DmaCsrValue) h2cCsrReadDataFifo  <- mkFIFOF;
    CounteredFIFOF#(csrReadReq)  csrRdReqStoreFifo <- mkCounteredFIFOF(CMPL_NPREQ_INFLIGHT_NUM);

    Reg#(PcieNonPostedRequst) npReqCreditCtrlReg <- mkReg(valueOf(NP_CREDIT_INCREMENT));
    Reg#(PcieNonPostedRequstCount) npReqCreditCntReg <- mkReg(0);


    rule genCsrWriteReq;
        let wrReq = cmplRequest.csrWriteReqFifoOut.first;
        cmplRequest.csrWriteReqFifoOut.deq;
        h2cCsrWriteDataFifo.enq(wrReq.value);
        h2cCsrWriteReqFifo.enq(wrReq.addr);
    endrule

    rule genCsrReadReq;
        let rdReq = cmplRequest.csrReadReqFifoOut.first;
        cmplRequest.csrReadReqFifoOut.deq;
        h2cCsrReadReqFifo.enq(rdReq.rdAddr);
        csrRdReqStoreFifo.enq(rdReq);
    endrule

    rule procCsrReadResp;
        let req = csrRdReqStoreFifo.first;
        let resp = h2cCsrReadDataFifo.first;
        cmplComplete.csrReadRespFifoIn(resp);
        cmplComplete.csrReadReqFifoIn(req);
    endrule

    rule npBackPressure;
        if (csrRdReqDescriptorFifo.getCurSize == fromInteger(valueOf(TDiv#(CMPL_NPREQ_INFLIGHT_NUM,2)))) begin
            npReqCreditCtrlReg <= valueOf(NP_CREDIT_NOCHANGE);
        end
        else begin
            npReqCreditCtrlReg <= valueOf(NP_CREDIT_INCREMENT);
        end
    endrule

    interface rawCompleterRequest;
        interface rawAxiStreamSlave = mkFifoInToRawPcieAxiStreamSlave#(cmplRequest.axiStreamFifoIn);
        method PcieNonPostedRequst nonPostedReqCreditIncrement = npReqCreditCtrlReg;
        method Action nonPostedReqCreditCnt(PcieNonPostedRequstCount nonPostedpReqCount);
            npReqCreditCntReg <= nonPostedpReqCount;
        endmethod
    endinterface

    interface rawCompleterComplete;
        interface rawAxiStreamSlave = mkFifoOutToRawPcieAxiStreamMaster#(cmplComplete.axiStreamFifoOut);
    endinterface

    interface h2cWrite;
        interface dataFifoOut = convertFifoToFifoOut(h2cCsrWriteDataFifo);
        interface reqFifoOut  = convertFifoToFifoOut(h2cCsrWriteReqFifo);
    endinterface

    interface h2cRead;
        interface reqFifoOut  = convertFifoToFifoOut(h2cCsrReadReqFifo);
        interface dataFifoIn  = convertFifoToFifoIn(h2cCsrReadDataFifo);
    endinterface

    // TODO: get internal registers value
    method DmaCsrValue getRegisterValue(DmaCsrAddr addr);
        return 0;
    method

endmodule

module mkWriteReqTo