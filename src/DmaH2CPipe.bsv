import FIFOF::*;
import Vector::*;

import SemiFifo::*;
import PrimUtils::*;
import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef 1 IDEA_CQ_CSR_DWORD_CNT;
typedef 2 IDEA_CC_CSR_DWORD_CNT;
typedef 4 IDEA_BYTE_CNT_OF_CSR;
typedef 4 IDEA_FIRST_BE_HIGH_VALID_PTR_OF_CSR;

typedef 64  CMPL_NPREQ_INFLIGHT_NUM;
typedef 20  CMPL_NPREQ_WAITING_CLKS;
typedef 2'b11 NP_CREDIT_INCREMENT;
typedef 2'b00 NP_CREDIT_NOCHANGE;

typedef 'h1F IDEA_CQ_TKEEP_OF_CSR;
typedef 'hF  IDEA_CC_TKEEP_OF_CSR;

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

interface DmaH2CPipe;
    // User Logic Ifc
    interface FifoOut#(DmaRequest)  reqFifoOut;
    interface FifoIn#(DmaCsrValue)  rdDataFifoIn;
    interface FifoOut#(DmaCsrValue) wrDataFifoOut;
    // Pcie Adapter Ifc
    interface FifoIn#(DataStream)  tlpDataFifoIn;
    interface FifoOut#(DataStream) tlpDataFifoOut;
    // TODO: Cfg Ifc
endinterface

(* synthesize *)
module mkDmaH2CPipe(DmaH2CPipe);
    
    FIFOF#(DataStream)  tlpInFifo    <- mkFIFOF;
    FIFOF#(DataStream)  tlpOutFifo   <- mkFIFOF;

    FIFOF#(DmaRequest)  reqOutFifo   <- mkFIFOF;
    FIFOF#(DmaCsrValue) dataInFifo   <- mkFIFOF;
    FIFOF#(DmaCsrValue) dataOutFifo  <- mkFIFOF

    FIFOF#(Tuple2#(DmaRequest, PcieCompleterRequestDescriptor)) pendingFifo <- mkSizedFIFOF(valueOf(CMPL_NPREQ_INFLIGHT_NUM));

    function PcieCompleterRequestDescriptor getDescriptorFromFirstBeat(DataStream stream);
        return unpack(truncate(stream.data));
    endfunction

    function Data getDataFromFirstBeat(DataStream stream);
        return stream.data >> valueOf(DES_CQ_DESCRIPTOR_WIDTH);
    endfunction

    Reg#(Bool) isInPacket <- mkReg(False);
    Reg#(UInt#(32)) illegalPcieReqCntReg <- mkReg(0);

    BytePtr csrBytes = fromInteger(valueOf(TDiv#(DMA_CSR_DATA_WIDTH, BYTE_WIDTH)));

    rule parseTlp;
        tlpInFifo.deq;
        let stream = tlpInFifo.first;
        isInPacket <= !stream.isLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(stream);
            case (descriptor.reqType) 
                fromInteger(valueOf(MEM_WRITE_REQ)): begin
                    $display("SIM INFO @ mkCompleterRequest: MemWrite Detect!");
                    if (descriptor.dwordCnt == fromInteger(valueOf(IDEA_CQ_CSR_DWORD_CNT))) begin
                        let firstData = getDataFromFirstBeat(stream);
                        DmaCsrValue wrValue = firstData[valueOf(DMA_CSR_ADDR_WIDTH)-1:0];
                        DmaCsrAddr wrAddr = getCsrAddrFromCqDescriptor(descriptor);
                        $display("SIM INFO @ mkCompleterRequest: Valid wrReq with Addr %h, data %h", wrAddr, wrValue);
                        let req = DmaRequest {
                            startAddr : wrAddr,
                            length    : zeroExtend(csrBytes),
                            isWrite   : True
                        };
                        reqOutFifo.enq(req);
                        dataOutFifo.enq(wrValue);
                    end
                    else begin
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                fromInteger(valueOf(MEM_READ_REQ)): begin
                    $display("SIM INFO @ mkCompleterRequest: MemRead Detect!");
                    let rdAddr = getCsrAddrFromCqDescriptor(descriptor);
                    let req = CsrReadReq{
                        startAddr : rdAddr,
                        length    : zeroExtend(csrBytes),
                        isWrite   : False
                    };
                    $display("SIM INFO @ mkCompleterRequest: Valid rdReq with Addr %h", rdAddr);
                    rdReqFifo.enq(req);
                    pendingFifo.enq(tuple2(req, descriptor));
                end
                default: illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
            endcase
        end
    endrule

    rule genTlp;
        let value = dataInFifo.first;
        dataInFifo.deq;
        let {req, cqDescriptor} = pendingFifo.first;
        pendingFifo.deq;
        let addr = req.startAddr;
        $display("SIM INFO @ mkCompleterComplete: Valid rdResp with Addr %h, data %h", addr, value);
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
            status          : fromInteger(valueOf(DES_CC_STAUS_SUCCESS)),
            dwordCnt        : fromInteger(valueOf(IDEA_CC_CSR_DWORD_CNT)),
            reserve2        : 0,
            isLockedReadCmpl: False,
            byteCnt         : fromInteger(valueOf(IDEA_BYTE_CNT_OF_CSR)),
            reserve3        : 0,
            addrType        : cqDescriptor.addrType,
            lowerAddr       : truncate(addr)
        };
        Data data = zeroExtend(pack(ccDescriptor));
        data = data | (zeroExtend(value) << valueOf(DES_CC_DESCRIPTOR_WIDTH));
        let stream = DataStream {
            data    : data,
            byteEn  : convertBytePtr2ByteEn(csrBytes),
            isFirst : True,
            isLast  : True
        };
        tlpOutFifo.enq(stream);
    endrule

    // User Logic Ifc
    interface reqFifoOut     = convertFifoToFifoOut(reqOutFifo);
    interface rdDataFifoIn   = convertFifoToFifoIn(dataInFifo);
    interface wrDataFifoOut  = convertFifoToFifoOut(dataOutFifo);
    // Pcie Adapter Ifc
    interface tlpDataFifoIn  = convertFifoToFifoIn(tlpInFifo);
    interface tlpDataFifoOut = convertFifoToFifoOut(tlpOutFifo);
endmodule
