import FIFOF::*;
import Vector::*;

import SemiFifo::*;
import PrimUtils::*;
import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import PcieAdapter::*;
import DmaTypes::*;

typedef 1 IDEA_CQ_CSR_DWORD_CNT;
typedef 2 IDEA_CC_CSR_DWORD_CNT;
typedef 4 IDEA_BYTE_CNT_OF_CSR;
typedef 4 IDEA_FIRST_BE_HIGH_VALID_PTR_OF_CSR;

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
    FIFOF#(DmaCsrValue) dataOutFifo  <- mkFIFOF;

    FIFOF#(Tuple2#(DmaRequest, PcieCompleterRequestDescriptor)) pendingFifo <- mkSizedFIFOF(valueOf(CMPL_NPREQ_INFLIGHT_NUM));

    function PcieCompleterRequestDescriptor getDescriptorFromFirstBeat(DataStream stream);
        return unpack(truncate(stream.data));
    endfunction

    function Data getDataFromFirstBeat(DataStream stream);
        return stream.data >> valueOf(DES_CQ_DESCRIPTOR_WIDTH);
    endfunction

    Reg#(Bool) isInPacket <- mkReg(False);
    Reg#(UInt#(32)) illegalPcieReqCntReg <- mkReg(0);

    DataBytePtr csrBytes = fromInteger(valueOf(TDiv#(DMA_CSR_DATA_WIDTH, BYTE_WIDTH)));

    function DmaCsrAddr getCsrAddrFromCqDescriptor(PcieCompleterRequestDescriptor descriptor);
        let addr = getAddrLowBits(zeroExtend(descriptor.address), descriptor.barAperture);
        // Only support one BAR now, no operation
        if (descriptor.barId == 0) begin
            addr = addr;
        end
        else begin
            addr = 0;
        end
        return truncate(addr << valueOf(TSub#(DMA_MEM_ADDR_WIDTH, DES_ADDR_WIDTH)));
    endfunction

    rule parseTlp;
        tlpInFifo.deq;
        let stream = tlpInFifo.first;
        isInPacket <= !stream.isLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(stream);
            case (descriptor.reqType) 
                fromInteger(valueOf(MEM_WRITE_REQ)): begin
                    $display("SIM INFO @ mkDmaH2CPipe: MemWrite Detect!");
                    let firstData = getDataFromFirstBeat(stream);
                    DmaCsrValue wrValue = truncate(firstData);
                    let wrAddr = getCsrAddrFromCqDescriptor(descriptor);
                    if (descriptor.dwordCnt == fromInteger(valueOf(IDEA_CQ_CSR_DWORD_CNT))) begin
                        $display("SIM INFO @ mkDmaH2CPipe: Valid wrReq with Addr %h, data %h", wrAddr, wrValue);
                        let req = DmaRequest {
                            startAddr : zeroExtend(wrAddr),
                            length    : zeroExtend(csrBytes),
                            isWrite   : True
                        };
                        reqOutFifo.enq(req);
                        dataOutFifo.enq(wrValue);
                    end
                    else begin
                        $display("SIM INFO @ mkDmaH2CPipe: Invalid wrReq with Addr %h, data %h", wrAddr, wrValue);
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                fromInteger(valueOf(MEM_READ_REQ)): begin
                    $display("SIM INFO @ mkDmaH2CPipe: MemRead Detect!");
                    let rdAddr = getCsrAddrFromCqDescriptor(descriptor);
                    let req = DmaRequest{
                        startAddr : zeroExtend(rdAddr),
                        length    : zeroExtend(csrBytes),
                        isWrite   : False
                    };
                    $display("SIM INFO @ mkDmaH2CPipe: Valid rdReq with Addr %h", rdAddr);
                    reqOutFifo.enq(req);
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
        $display("SIM INFO @ mkDmaH2CPipe: Valid rdResp with Addr %h, data %h", addr, value);
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
