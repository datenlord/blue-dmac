import FIFOF::*;
import Vector::*;
import RegFile::*;

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
    interface FifoOut#(CsrRequest)  csrReqFifoOut;
    interface FifoIn#(CsrResponse)  csrRespFifoIn;
    // Pcie Adapter Ifc
    interface FifoIn#(DataStream)  tlpDataFifoIn;
    interface FifoOut#(DataStream) tlpDataFifoOut;
    // TODO: Cfg Ifc
endinterface

(* synthesize *)
module mkDmaH2CPipe(DmaH2CPipe);
    
    FIFOF#(DataStream)  tlpInFifo    <- mkFIFOF;
    FIFOF#(DataStream)  tlpOutFifo   <- mkFIFOF;

    FIFOF#(CsrRequest)   reqOutFifo   <- mkFIFOF;
    FIFOF#(CsrResponse)  respInFifo   <- mkFIFOF;

    FIFOF#(Tuple2#(CsrRequest, PcieCompleterRequestDescriptor)) pendingFifo <- mkSizedFIFOF(valueOf(CMPL_NPREQ_INFLIGHT_NUM));

    function PcieCompleterRequestDescriptor getDescriptorFromFirstBeat(DataStream stream);
        return unpack(truncate(stream.data));
    endfunction

    function Data getDataFromFirstBeat(DataStream stream);
        return stream.data >> valueOf(DES_CQ_DESCRIPTOR_WIDTH);
    endfunction

    Reg#(Bool) isInPacket <- mkReg(False);
    Reg#(UInt#(32)) illegalPcieReqCntReg <- mkReg(0);

    DataBytePtr csrBytes = fromInteger(valueOf(TDiv#(DMA_CSR_DATA_WIDTH, BYTE_WIDTH)));

    // This function returns DW addr pointing to inner registers, where byteAddr = DWordAddr << 2
    // The registers in the hw are all of 32bit DW type
    function DmaCsrAddr getCsrAddrFromCqDescriptor(PcieCompleterRequestDescriptor descriptor);
        // Only care about low bits, because the offset is allocated. 
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
        tlpInFifo.deq;
        let stream = tlpInFifo.first;
        isInPacket <= !stream.isLast;
        if (!isInPacket) begin
            let descriptor  = getDescriptorFromFirstBeat(stream);
            case (descriptor.reqType) 
                fromInteger(valueOf(MEM_WRITE_REQ)): begin
                    $display($time, "ns SIM INFO @ mkDmaH2CPipe: MemWrite Detect!");
                    let firstData = getDataFromFirstBeat(stream);
                    DmaCsrValue wrValue = truncate(firstData);
                    let wrAddr = getCsrAddrFromCqDescriptor(descriptor);
                    if (descriptor.dwordCnt == fromInteger(valueOf(IDEA_CQ_CSR_DWORD_CNT))) begin
                        $display($time, "ns SIM INFO @ mkDmaH2CPipe: Valid wrReq with Addr %h, data %h", wrAddr << valueOf(TLog#(DWORD_BYTES)), wrValue);
                        let req = CsrRequest {
                            addr      : wrAddr,
                            value     : wrValue,
                            isWrite   : True
                        };
                        reqOutFifo.enq(req);
                    end
                    else begin
                        $display($time, "ns SIM INFO @ mkDmaH2CPipe: Invalid wrReq with Addr %h, data %h", wrAddr << valueOf(TLog#(DWORD_BYTES)), wrValue);
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                fromInteger(valueOf(MEM_READ_REQ)): begin
                    $display($time, "ns SIM INFO @ mkDmaH2CPipe: MemRead Detect!");
                    let rdAddr = getCsrAddrFromCqDescriptor(descriptor);
                    let req = CsrRequest{
                        addr      : rdAddr,
                        value     : zeroExtend(csrBytes),
                        isWrite   : False
                    };
                    $display($time, "ns SIM INFO @ mkDmaH2CPipe: Valid rdReq with Addr %h", rdAddr << valueOf(TLog#(DWORD_BYTES)));
                    reqOutFifo.enq(req);
                    pendingFifo.enq(tuple2(req, descriptor));
                end
                default: illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
            endcase
        end
    endrule

    rule genTlp;
        let resp = respInFifo.first;
        let addr = resp.addr;
        let value = resp.value;
        respInFifo.deq;
        let {req, cqDescriptor} = pendingFifo.first;
        if (addr == req.addr) begin
            pendingFifo.deq;
            $display($time, "ns SIM INFO @ mkDmaH2CPipe: Valid rdResp with Addr %h, data %h", addr, value);
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
        end
        else begin
            $display($time, "ns SIM ERROR @ mkDmaH2CPipe: InValid rdResp with Addr %h, data %h and Expect Addr %h", addr, value, req.addr);
        end
    endrule

    // User Logic Ifc
    interface csrReqFifoOut  = convertFifoToFifoOut(reqOutFifo);
    interface csrRespFifoIn  = convertFifoToFifoIn(respInFifo);
    // Pcie Adapter Ifc
    interface tlpDataFifoIn  = convertFifoToFifoIn(tlpInFifo);
    interface tlpDataFifoOut = convertFifoToFifoOut(tlpOutFifo);
endmodule



