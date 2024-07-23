import FIFOF::*;

import SemiFifo::*;
import PrimUtils::*;
import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef 1 IDEA_DWORD_CNT_OF_CSR;
typedef 4 IDEA_FIRST_BE_HIGH_VALID_PTR_OF_CSR;

typedef 64  CMPL_NPREQ_INFLIGHT_NUM;
typedef 20  CMPL_NPREQ_WAITING_CLKS;
typedef 2'b11 NP_CREDIT_INCREMENT;
typedef 2'b00 NP_CREDIT_NOCHANGE;

typedef PcieAxiStream#(PCIE_COMPLETER_REQUEST_TUSER_WIDTH)  CmplReqAxiStream;
typedef PcieAxiStream#(PCIE_COMPLETER_COMPLETE_TUSER_WIDTH) CmplCmplAxiStream;

typedef struct {
    DmaCsrAddr  addr;
    DmaCsrValue value;
} CsrWriteReq deriving(Bits, Eq, Bounded);

instance FShow#(CsrWriteReq);
    function Fmt fshow(CsrWriteReq wrReq);
        return ($format("<CsrWriteRequest: address=%h, value=%h", wrReq.addr, wrReq.value));
    endfunction
endinstance

typedef DmaCsrValue CsrReadResp;

typedef struct {
    DmaCsrAddr addr;
    PcieCompleterRequestDescriptor cqDescriptor;
} CsrReadReq deriving(Bits, Eq, Bounded, FShow);

interface DmaCompleter;
    (* prefix = "" *) interface RawPcieCompleterRequest  rawCompleterRequest;
    (* prefix = "" *) interface RawPcieCompleterComplete rawCompleterComplete;
    interface DmaHostToCardWrite       h2cWrite;
    interface DmaHostToCardRead        h2cRead;
    method DmaCsrValue getRegisterValue(DmaCsrAddr addr);
endinterface

interface CompleterRequest;
    interface FifoIn#(CmplReqAxiStream) axiStreamFifoIn;
    interface FifoOut#(CsrWriteReq)     csrWriteReqFifoOut;
    interface FifoOut#(CsrReadReq)      csrReadReqFifoOut;
endinterface

interface CompleterComplete;
    interface FifoOut#(CmplCmplAxiStream) axiStreamFifoOut;
    interface FifoIn#(CsrReadResp)        csrReadRespFifoIn;
    interface FifoIn#(CsrReadReq)         csrReadReqFifoIn;
endinterface

// PcieCompleter does not support straddle mode now
// The completer is designed only for CSR Rd/Wr, and will ignore any len>32bit requests 
module mkCompleterRequest(CompleterRequest);
    FIFOF#(CmplReqAxiStream)   inFifo    <- mkFIFOF;
    FIFOF#(CsrWriteReq)        wrReqFifo <- mkFIFOF;
    FIFOF#(CsrReadReq)         rdReqFifo <- mkFIFOF;

    Reg#(Bool) isInPacket <- mkReg(False);
    Reg#(UInt#(32)) illegalPcieReqCntReg <- mkReg(0);

    function PcieCompleterRequestDescriptor getDescriptorFromFirstBeat(CmplReqAxiStream axiStream);
        return unpack(axiStream.tData[valueOf(DES_CQ_DESCRIPTOR_WIDTH)-1:0]);
    endfunction

    function Data getDataFromFirstBeat(CmplReqAxiStream axiStream);
        return axiStream.tData >> valueOf(DES_CQ_DESCRIPTOR_WIDTH);
    endfunction

    function Bool isFirstBytesAllValid(PcieCompleterRequestSideBandFrame sideBand);
        return (sideBand.firstByteEn[valueOf(IDEA_FIRST_BE_HIGH_VALID_PTR_OF_CSR)-1] == 1);
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

    rule parseTlp;
        inFifo.deq;
        let axiStream = inFifo.first;
        PcieCompleterRequestSideBandFrame sideBand = unpack(axiStream.tUser);
        isInPacket <= !axiStream.tLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(axiStream);
            // TODO: parity check!
            case (descriptor.reqType) 
                fromInteger(valueOf(MEM_WRITE_REQ)): begin
                    if (descriptor.dwordCnt == fromInteger(valueOf(IDEA_DWORD_CNT_OF_CSR)) && isFirstBytesAllValid(sideBand)) begin
                        let firstData = getDataFromFirstBeat(axiStream);
                        DmaCsrValue wrValue = firstData[valueOf(DMA_CSR_ADDR_WIDTH)-1:0];
                        DmaCsrAddr wrAddr = getCsrAddrFromCqDescriptor(descriptor);
                        let wrReq = CsrWriteReq {
                            addr    : wrAddr,
                            value   : wrValue
                        };
                        wrReqFifo.enq(wrReq);
                    end
                    else begin
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                fromInteger(valueOf(MEM_READ_REQ)): begin
                    let rdReqAddr = getCsrAddrFromCqDescriptor(descriptor);
                    let rdReq = CsrReadReq{
                        addr: rdReqAddr,
                        cqDescriptor: descriptor
                    };
                    rdReqFifo.enq(rdReq);
                end
                default: begin $display("INFO"); illegalPcieReqCntReg <= illegalPcieReqCntReg + 1; end 
            endcase
        end
    endrule

    interface axiStreamFifoIn    = convertFifoToFifoIn(inFifo);
    interface csrWriteReqFifoOut = convertFifoToFifoOut(wrReqFifo);
    interface csrReadReqFifoOut  = convertFifoToFifoOut(rdReqFifo);
endmodule

module mkCompleterComplete(CompleterComplete);
    FIFOF#(CmplCmplAxiStream) outFifo    <- mkFIFOF;
    FIFOF#(CsrReadResp)       rdRespFifo <- mkFIFOF;
    FIFOF#(CsrReadReq)        rdReqFifo  <- mkFIFOF;

    // TODO: the logic of cc, not completed
    rule genTlp;
        let value = rdRespFifo.first;
        rdRespFifo.deq;
        let cqDescriptor = rdReqFifo.first.cqDescriptor;
        let addr = rdReqFifo.first.addr;
        rdReqFifo.deq;
        let ccDescriptor = PcieCompleterCompleteDescriptor {
            reserve0        : 0,
            attributes      : cqDescriptor.attributes,
            trafficClass    : cqDescriptor.trafficClass,
            completerIdEn   : False,
            completerId     : 0,
            tag             : cqDescriptor.tag,
            requesterId     : cqDescriptor.requesterId,
            reserve1        : 0,
            isPoisoned      : False,
            status          : 0,
            dwordCnt        : 0,
            reserve2        : 0,
            isLockedReadCmpl: False,
            byteCnt         : 0,
            reserve3        : 0,
            addrType        : 0,
            lowerAddr       : 0
        };
        Data data = zeroExtend(pack(ccDescriptor));
        data = data | (zeroExtend(value) << valueOf(DES_CC_DESCRIPTOR_WIDTH));
        let axiStream = CmplCmplAxiStream {
            tData : data,
            tKeep : 0,
            tLast : True,
            tUser : 0
        };
        outFifo.enq(axiStream);
    endrule

    interface axiStreamFifoOut   = convertFifoToFifoOut(outFifo);
    interface csrReadRespFifoIn  = convertFifoToFifoIn(rdRespFifo);
    interface csrReadReqFifoIn   = convertFifoToFifoIn(rdReqFifo);
endmodule

(* synthesize *)
module mkDmaCompleter(DmaCompleter);
    CompleterRequest  cmplRequest  <- mkCompleterRequest;
    CompleterComplete cmplComplete <- mkCompleterComplete;

    FIFOF#(DmaCsrValue) h2cCsrWriteDataFifo <- mkFIFOF;
    FIFOF#(DmaCsrAddr)  h2cCsrWriteReqFifo  <- mkFIFOF;
    FIFOF#(DmaCsrAddr)  h2cCsrReadReqFifo   <- mkFIFOF;
    FIFOF#(DmaCsrValue) h2cCsrReadDataFifo  <- mkFIFOF;
    CounteredFIFOF#(CsrReadReq)  csrRdReqStoreFifo <- mkCounteredFIFOF(valueOf(CMPL_NPREQ_INFLIGHT_NUM));

    Reg#(PcieNonPostedRequst) npReqCreditCtrlReg <- mkReg(fromInteger(valueOf(NP_CREDIT_INCREMENT)));
    Reg#(PcieNonPostedRequstCount) npReqCreditCntReg <- mkReg(0);

    let rawAxiStreamSlaveIfc  <- mkFifoInToRawPcieAxiStreamSlave(cmplRequest.axiStreamFifoIn);
    let rawAxiStreamMasterIfc <- mkFifoOutToRawPcieAxiStreamMaster(cmplComplete.axiStreamFifoOut);

    rule genCsrWriteReq;
        let wrReq = cmplRequest.csrWriteReqFifoOut.first;
        cmplRequest.csrWriteReqFifoOut.deq;
        h2cCsrWriteDataFifo.enq(wrReq.value);
        h2cCsrWriteReqFifo.enq(wrReq.addr);
    endrule

    rule genCsrReadReq;
        let rdReq = cmplRequest.csrReadReqFifoOut.first;
        cmplRequest.csrReadReqFifoOut.deq;
        h2cCsrReadReqFifo.enq(rdReq.addr);
        csrRdReqStoreFifo.enq(rdReq);
    endrule

    rule procCsrReadResp;
        let req = csrRdReqStoreFifo.first;
        let resp = h2cCsrReadDataFifo.first;
        cmplComplete.csrReadRespFifoIn.enq(resp);
        cmplComplete.csrReadReqFifoIn.enq(req);
    endrule

    rule npBackPressure;
        if (csrRdReqStoreFifo.getCurSize == fromInteger(valueOf(TDiv#(CMPL_NPREQ_INFLIGHT_NUM,2)))) begin
            npReqCreditCtrlReg <= fromInteger(valueOf(NP_CREDIT_NOCHANGE));
        end
        else begin
            npReqCreditCtrlReg <= fromInteger(valueOf(NP_CREDIT_INCREMENT));
        end
    endrule

    interface RawPcieCompleterRequest rawCompleterRequest;
        interface rawAxiStreamSlave = rawAxiStreamSlaveIfc;
        method PcieNonPostedRequst nonPostedReqCreditIncrement = npReqCreditCtrlReg;
        method Action nonPostedReqCreditCnt(PcieNonPostedRequstCount nonPostedpReqCount);
            npReqCreditCntReg <= nonPostedpReqCount;
        endmethod
    endinterface

    interface RawPcieCompleterComplete rawCompleterComplete;
        interface rawAxiStreamMaster = rawAxiStreamMasterIfc;
    endinterface

    interface DmaHostToCardWrite h2cWrite;
        interface dataFifoOut = convertFifoToFifoOut(h2cCsrWriteDataFifo);
        interface reqFifoOut  = convertFifoToFifoOut(h2cCsrWriteReqFifo);
    endinterface

    interface DmaHostToCardRead h2cRead;
        interface reqFifoOut  = convertFifoToFifoOut(h2cCsrReadReqFifo);
        interface dataFifoIn  = convertFifoToFifoIn(h2cCsrReadDataFifo);
    endinterface

    // TODO: get internal registers value
    method DmaCsrValue getRegisterValue(DmaCsrAddr addr);
        return 0;
    endmethod

endmodule
