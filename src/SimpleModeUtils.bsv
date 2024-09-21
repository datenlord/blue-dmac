import Vector::*;
import RegFile::*;
import GetPut::*;
import SemiFifo::*;
import FIFOF::*;
import BRAM::*;

import DmaTypes::*;
import StreamUtils::*;

function Bit#(TMul#(2,n)) doubleExtend(Bit#(n) lo, Bit#(n) hi) provisos(Add#(1, _a, n), Add#(_b, n, TMul#(2, n)));
    return zeroExtend(lo) & (zeroExtend(hi) << valueOf(n));
endfunction

interface DmaSimpleCore;
    // from H2C user Ifc, where the addr is already aligned to DWord
    interface FifoIn#(CsrRequest)   reqFifoIn;
    interface FifoOut#(CsrResponse) respFifoOut;
    // to external peripherals (connect to dummy reg in test)
    interface FifoIn#(CsrResponse) externalRespFifoIn;
    interface FifoOut#(CsrRequest) externalReqFifoOut;
    // new dma descriptor (conncet to H2C user Ifc)
    interface Vector#(DMA_PATH_NUM, FifoOut#(DmaRequest))  c2hReqFifoOut;
endinterface

module mkDmaSimpleCore(DmaSimpleCore);
    FIFOF#(CsrRequest)  internalReqFifo  <- mkFIFOF;
    FIFOF#(CsrRequest)  externalReqFifo  <- mkFIFOF;

    FIFOF#(CsrResponse) internalRespFifo <- mkFIFOF;
    FIFOF#(CsrResponse) externalRespFifo <- mkFIFOF;
    FIFOF#(CsrResponse) tempRespFifo     <- mkFIFOF;

    RegFile#(DmaRegIndex, DmaCsrValue) controlRegFile <- mkRegFileFull; 

    Vector#(DMA_PATH_NUM, FifoOut#(DmaRequest)) c2hReqFifoOutIfc = newVector;
    Vector#(DMA_PATH_NUM, PhyAddrBram) paTableBram = newVector;
    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        paTableBram[pathIdx] <- mkPhyAddrBram;
        c2hReqFifoOutIfc[pathIdx] = paTableBram[pathIdx].paReqFifoOut;
    end
    
    function DmaRegBlockIdx getRegBlockIdx (DmaCsrAddr csrAddr);
        DmaRegBlockIdx idx = truncate(csrAddr >> valueOf(DMA_INTERNAL_REG_BLOCK_WIDTH)); 
        return idx;
    endfunction

    rule map;
        let req = internalReqFifo.first;
        internalReqFifo.deq;
        let blockIdx = getRegBlockIdx(req.addr);
        DmaRegIndex regIdx = truncate(req.addr);
        // Write Request
        if (req.isWrite) begin
            // Block 0 : DMA Inner Ctrl Regs
            if (blockIdx == 0) begin
                if (regIdx == fromInteger(valueOf(REG_DESC_CNTL_0))) begin
                    let addrLo = controlRegFile.sub(fromInteger(valueOf(REG_DESC_ADDR_LO_0)));
                    let addrHi = controlRegFile.sub(fromInteger(valueOf(REG_DESC_ADDR_HI_0)));
                    let length  = controlRegFile.sub(fromInteger(valueOf(REG_DESC_LEN_0)));
                    let vaHeaderLo = controlRegFile.sub(fromInteger(valueOf(REG_VA_HEADER_LO_0)));
                    let vaHeaderHi = controlRegFile.sub(fromInteger(valueOf(REG_VA_HEADER_HI_0)));
                    let vaHeader = doubleExtend(vaHeaderLo, vaHeaderHi);
                    Bool isWrite = unpack(truncate(req.value));
                    let desc = DmaRequest {
                        startAddr: doubleExtend(addrLo, addrHi),
                        length   : length,
                        isWrite  : isWrite
                    };
                    if (desc.startAddr > 0) begin
                        paTableBram[0].vaReqFifoIn.enq(desc);
                        paTableBram[0].vaHeader.put(vaHeader);
                    end
                end
                else if (regIdx == fromInteger(valueOf(REG_DESC_CNTL_1))) begin
                    let addrLo = controlRegFile.sub(fromInteger(valueOf(REG_DESC_ADDR_LO_1)));
                    let addrHi = controlRegFile.sub(fromInteger(valueOf(REG_DESC_ADDR_HI_1)));
                    let length  = controlRegFile.sub(fromInteger(valueOf(REG_DESC_LEN_1)));
                    let vaHeaderLo = controlRegFile.sub(fromInteger(valueOf(REG_VA_HEADER_LO_1)));
                    let vaHeaderHi = controlRegFile.sub(fromInteger(valueOf(REG_VA_HEADER_HI_1)));
                    let vaHeader = doubleExtend(vaHeaderLo, vaHeaderHi);
                    Bool isWrite = unpack(truncate(req.value));
                    let desc = DmaRequest {
                        startAddr: doubleExtend(addrLo, addrHi),
                        length   : length,
                        isWrite  : isWrite
                    };
                    if (desc.startAddr > 0) begin
                        paTableBram[1].vaReqFifoIn.enq(desc);
                        paTableBram[1].vaHeader.put(vaHeader);
                    end
                end
                // if not doorbell, write the register
                else begin
                    controlRegFile.upd(regIdx, req.value);
                end
            end
            // Block 1~2 : Channel 0 Va-Pa Table
            else if (blockIdx <= fromInteger(valueOf(PA_TABLE0_BLOCK_OFFSET))) begin
                let vaReq = CsrRequest {
                    addr    : req.addr - fromInteger(valueOf(DMA_PA_TABLE0_OFFSET)),
                    value   : req.value,
                    isWrite : True
                };
                paTableBram[0].paSetFifoIn.enq(vaReq);
            end
            // Block 3~4 : Channel 1 Va-Pa Table
            else if (blockIdx <= fromInteger(valueOf(PA_TABLE1_BLOCK_OFFSET))) begin
                let vaReq = CsrRequest {
                    addr    : req.addr - fromInteger(valueOf(DMA_PA_TABLE1_OFFSET)),
                    value   : req.value,
                    isWrite : True
                };
                paTableBram[1].paSetFifoIn.enq(vaReq);
            end
            // Block 5~N : External Peripherals Regs
            else begin
                req.addr = req.addr - fromInteger(valueOf(DMA_EX_REG_OFFSET));
                externalReqFifo.enq(req);
            end
        end
        // Read Request
        else begin
            if (blockIdx == 0) begin
                if (regIdx <= fromInteger(valueOf(DMA_USING_REG_LEN))) begin
                    let value = controlRegFile.sub(regIdx);
                    let resp = CsrResponse {
                        addr  : req.addr,
                        value : value
                    };
                    tempRespFifo.enq(resp);
                end
                else begin
                    let resp = CsrResponse {
                        addr  : req.addr,
                        value : 0
                    };
                    tempRespFifo.enq(resp);
                end
            end
            else if (blockIdx > fromInteger(valueOf(PA_TABLE1_BLOCK_OFFSET))) begin
                req.addr = req.addr - fromInteger(valueOf(DMA_EX_REG_OFFSET));
                externalReqFifo.enq(req);
            end
            else begin
                let resp = CsrResponse {
                    addr  : req.addr,
                    value : 0
                };
                tempRespFifo.enq(resp);
            end
        end
    endrule

    rule muxResp;
        if (tempRespFifo.notEmpty) begin
            tempRespFifo.deq;
            internalRespFifo.enq(tempRespFifo.first);
        end
        else if (externalRespFifo.notEmpty) begin
            externalRespFifo.deq;
            let extResp = externalRespFifo.first;
            extResp.addr = extResp.addr + fromInteger(valueOf(DMA_EX_REG_OFFSET));
            internalRespFifo.enq(extResp);
        end
    endrule

    interface reqFifoIn   = convertFifoToFifoIn(internalReqFifo);
    interface respFifoOut = convertFifoToFifoOut(internalRespFifo);

    interface externalReqFifoOut = convertFifoToFifoOut(externalReqFifo);
    interface externalRespFifoIn = convertFifoToFifoIn(externalRespFifo);

    interface c2hReqFifoOut = c2hReqFifoOutIfc;
endmodule

typedef 3 BRAM_LATENCY;

interface PhyAddrBram;
    // Address transfer
    interface FifoIn#(DmaRequest)  vaReqFifoIn;
    interface FifoOut#(DmaRequest) paReqFifoOut;
    // va-pa table set
    interface FifoIn#(CsrRequest)  paSetFifoIn;
    interface Put#(DmaMemAddr)     vaHeader;
endinterface

// This module does not check if the request address is valid(in MR)
module mkPhyAddrBram(PhyAddrBram);
    FIFOF#(DmaRequest) vaReqFifo <- mkFIFOF;
    FIFOF#(DmaRequest) paReqFifo <- mkFIFOF;
    FIFOF#(CsrRequest) paSetFifo <- mkFIFOF;
    FIFOF#(DmaRequest) pendingFifo <- mkSizedFIFOF(valueOf(BRAM_LATENCY));

    Reg#(DmaMemAddr) vaHeaderReg <- mkReg(0);

    BRAM1Port#(PaBramAddr, DmaCsrValue) phyAddrLoBram <- mkBRAM1Server(defaultValue);
    BRAM1Port#(PaBramAddr, DmaCsrValue) phyAddrHiBram <- mkBRAM1Server(defaultValue);

    function Bool isLoAddr(DmaCsrAddr addr);
        return unpack(addr[0]);
    endfunction

    function PaBramAddr convertCsrAddrToBramAddr(DmaCsrAddr csrAddr);
        let addr = csrAddr >> 1;
        return truncate(addr);
    endfunction

    function PaBramAddr convertDmaAddrToBramAddr(DmaMemAddr dmaAddr);
        let pageIdx = (dmaAddr - vaHeaderReg) >> valueOf(HUGE_PAGE_SIZE_WIDTH);
        return truncate(pageIdx);
    endfunction

    rule putVaReq;
        // if is setting va-pa table
        if (paSetFifo.notEmpty) begin
            let paSet = paSetFifo.first;
            let bramAddr = convertCsrAddrToBramAddr(paSet.addr);
            if (isLoAddr(paSet.addr)) begin
                let bramReq = BRAMRequest {
                    write   : True,
                    responseOnWrite : False,
                    address : bramAddr,
                    datain  : paSet.value
                };
                phyAddrLoBram.portA.request.put(bramReq);
            end
            else begin
                let bramReq = BRAMRequest {
                    write   : True,
                    responseOnWrite : False,
                    address : bramAddr,
                    datain  : paSet.value
                };
                phyAddrHiBram.portA.request.put(bramReq);
            end
        end
        // if is getting phy address
        else begin
            let vaReq = vaReqFifo.first;
            let bramReq = BRAMRequest {
                write   : False,
                responseOnWrite : False,
                address : convertDmaAddrToBramAddr(vaReq.startAddr),
                datain  : 0
            };
            phyAddrLoBram.portA.request.put(bramReq);
            phyAddrHiBram.portA.request.put(bramReq);
            pendingFifo.enq(vaReq);
        end
    endrule

    rule getPaReq;
        let pa_lo <- phyAddrLoBram.portA.response.get;
        let pa_hi <- phyAddrHiBram.portA.response.get;
        let pa = zeroExtend(pa_hi << valueOf(DMA_CSR_ADDR_WIDTH)) & zeroExtend(pa_lo);
        let oriReq = pendingFifo.first;
        pendingFifo.deq;
        oriReq.startAddr = pa;
        paReqFifo.enq(oriReq);
    endrule

    interface vaReqFifoIn  = convertFifoToFifoIn(vaReqFifo);
    interface paReqFifoOut = convertFifoToFifoOut(paReqFifo);
    interface paSetFifoIn  = convertFifoToFifoIn(paSetFifo);
    interface Put vaHeader;
        method Action put(DmaMemAddr vaHeadAddr);
            vaHeaderReg <= vaHeadAddr;
        endmethod
    endinterface
endmodule

typedef 12 DUMMY_ADDR_WIDTH;
typedef Bit#(DUMMY_ADDR_WIDTH) DummyAddr;

interface GenericCsr;
    interface FifoIn#(CsrRequest)    reqFifoIn;
    interface FifoOut#(CsrResponse)  respFifoOut;
endinterface

module mkDummyCsr(GenericCsr);
    FIFOF#(CsrRequest)  reqFifo  <- mkFIFOF;
    FIFOF#(CsrResponse) respFifo <- mkFIFOF;
    FIFOF#(DmaCsrAddr)  pendingFifo <- mkSizedFIFOF(valueOf(BRAM_LATENCY));
    BRAM1Port#(DummyAddr, DmaCsrValue) bram <- mkBRAM1Server(defaultValue);

    rule request;
        let req = reqFifo.first;
        reqFifo.deq;
        let bramReq = BRAMRequest {
            write   : req.isWrite,
            responseOnWrite : False,
            address : truncate(req.addr),
            datain  : req.value
        };
        bram.portA.request.put(bramReq);
    endrule

    rule response;
        let value <- bram.portA.response.get;
        let addr = pendingFifo.first;
        pendingFifo.deq;
        let resp = CsrResponse {
            addr  : addr,
            value : value
        };
        respFifo.enq(resp);
    endrule

    interface reqFifoIn   = convertFifoToFifoIn(reqFifo);
    interface respFifoOut = convertFifoToFifoOut(respFifo);
endmodule
