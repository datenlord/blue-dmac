import FIFOF::*;
import GetPut :: *;
import Vector::*;

import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;
import PcieAxiStreamTypes::*;
import PrimUtils::*;
import StreamUtils::*;
import PcieDescriptorTypes::*;


typedef Bit#(BUS_BOUNDARY_WIDTH)            PcieTlpMaxMaxPayloadSize;
typedef Bit#(TLog#(BUS_BOUNDARY_WIDTH))     PcieTlpSizeWidth;

typedef 128                                 DEFAULT_TLP_SIZE;
typedef TLog#(DEFAULT_TLP_SIZE)             DEFAULT_TLP_SIZE_WIDTH;

typedef 3                                   PCIE_TLP_SIZE_SETTING_WIDTH;
typedef Bit#(PCIE_TLP_SIZE_SETTING_WIDTH)   PcieTlpSizeSetting;      

typedef TAdd#(1, TLog#(TDiv#(BUS_BOUNDARY, BYTE_EN_WIDTH))) DATA_BEATS_WIDTH;
typedef Bit#(DATA_BEATS_WIDTH)                              DataBeats;                 

typedef 4 CHUNK_COMPUTE_LATENCY;
// Split the input DmaRequest Info MRRS aligned chunkReqs
interface ChunkCompute;
    interface FifoIn#(DmaExtendRequest)  dmaRequestFifoIn;
    interface FifoOut#(DmaRequest)       chunkRequestFifoOut;
    interface FifoOut#(DmaMemAddr)       chunkCntFifoOut;
    interface Put#(PcieTlpSizeSetting)   setTlpMaxSize;
endinterface 

module mkChunkComputer (TRXDirection direction, ChunkCompute ifc);

    FIFOF#(DmaExtendRequest)  inputFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)        outputFifo <- mkFIFOF;
    FIFOF#(Tuple2#(DmaExtendRequest, DmaMemAddr))  pipeFifo <- mkFIFOF;
    FIFOF#(DmaMemAddr)        tlpCntFifo <- mkSizedFIFOF(valueOf(CHUNK_COMPUTE_LATENCY));

    Reg#(DmaMemAddr) newChunkPtrReg      <- mkReg(0);
    Reg#(DmaMemAddr) totalLenRemainReg   <- mkReg(0);
    Reg#(Bool)       isSplittingReg      <- mkReg(False);
    
    Reg#(DmaMemAddr)       tlpMaxSizeReg      <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidthReg <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   

    function Bool hasBoundary(DmaExtendRequest request);
        let highIdx = request.endAddr >> tlpMaxSizeWidthReg;
        let lowIdx = request.startAddr >> tlpMaxSizeWidthReg;
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getTlpCnts(DmaExtendRequest request);
        let highIdx = request.endAddr >> tlpMaxSizeWidthReg;
        let lowIdx = request.startAddr >> tlpMaxSizeWidthReg;
        return (highIdx - lowIdx + 1);
    endfunction

    function DmaMemAddr getOffset(DmaExtendRequest request);
        // MPS - startAddr % MPS, MPS means MRRS when the module is set to RX mode
        DmaMemAddr remainderOfMps = zeroExtend(PcieTlpMaxMaxPayloadSize'(request.startAddr[tlpMaxSizeWidthReg-1:0]));
        DmaMemAddr offsetOfMps = tlpMaxSizeReg - remainderOfMps;    
        return offsetOfMps;
    endfunction

    rule getfirstChunkLen;
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffset(request);
        let firstLen = (request.length > tlpMaxSizeReg) ? tlpMaxSizeReg : request.length;
        let firstChunkLen = hasBoundary(request) ? offset : firstLen;
        pipeFifo.enq(tuple2(request, firstChunkLen));
        let tlpCnt = getTlpCnts(request);
        tlpCntFifo.enq(tlpCnt);
    endrule

    rule execChunkCompute;
        let {request, firstChunkLen} = pipeFifo.first;
        if (isSplittingReg) begin   // !isFirst
            if (totalLenRemainReg <= tlpMaxSizeReg) begin 
                isSplittingReg <= False; 
                outputFifo.enq(DmaRequest {
                    startAddr : newChunkPtrReg,
                    length    : totalLenRemainReg,
                    isWrite   : False
                });
                pipeFifo.deq;
                totalLenRemainReg <= 0;
            end 
            else begin
                isSplittingReg <= True;
                outputFifo.enq(DmaRequest {
                    startAddr : newChunkPtrReg,
                    length    : tlpMaxSizeReg,
                    isWrite   : False
                });
                newChunkPtrReg <= newChunkPtrReg + tlpMaxSizeReg;
                totalLenRemainReg <= totalLenRemainReg - tlpMaxSizeReg;
            end
        end 
        else begin   // isFirst
            let remainderLength = request.length - firstChunkLen;
            Bool isSplittingNextCycle = (remainderLength > 0);
            isSplittingReg <= isSplittingNextCycle;
            outputFifo.enq(DmaRequest {
                startAddr : request.startAddr,
                length    : firstChunkLen,
                isWrite   : False
            }); 
            if (!isSplittingNextCycle) begin 
                pipeFifo.deq; 
            end
            newChunkPtrReg <= request.startAddr + firstChunkLen;
            totalLenRemainReg <= remainderLength;
        end
    endrule

    interface  dmaRequestFifoIn = convertFifoToFifoIn(inputFifo);
    interface  chunkRequestFifoOut = convertFifoToFifoOut(outputFifo);
    interface  chunkCntFifoOut  = convertFifoToFifoOut(tlpCntFifo);

    interface Put setTlpMaxSize;
        method Action put (PcieTlpSizeSetting tlpSizeSetting);
            let setting = tlpSizeSetting;
            setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1] = (direction == DMA_TX) ? 0 : setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1];
            DmaMemAddr defaultTlpMaxSize = fromInteger(valueOf(DEFAULT_TLP_SIZE));
            tlpMaxSizeReg <= DmaMemAddr'(defaultTlpMaxSize << setting);
            PcieTlpSizeWidth defaultTlpMaxSizeWidth = fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH));
            tlpMaxSizeWidthReg <= PcieTlpSizeWidth'(defaultTlpMaxSizeWidth + zeroExtend(setting));
        endmethod
    endinterface
    
endmodule

// Split the single input DataStream to a list of DataStream chunks
//  - Chunks cannot violate bus boundary requirement
//  - Only the first and the last chunk can be shorter than MaxPayloadSize
//  - Other chunks length must equal to MaxPayloadSize
//  - The module may block the pipeline if one input beat is splited to two beats
interface ChunkSplit;
    interface FifoIn#(DataStream)       dataFifoIn;
    interface FifoIn#(DmaExtendRequest) reqFifoIn;
    interface FifoOut#(DataStream)      chunkDataFifoOut;
    interface FifoOut#(DmaRequest)      chunkReqFifoOut;
    interface Put#(PcieTlpSizeSetting)  setTlpMaxSize;
endinterface

module mkChunkSplit(TRXDirection direction, ChunkSplit ifc);
    FIFOF#(DataStream)  dataInFifo       <- mkFIFOF;
    FIFOF#(DataStream)  chunkOutFifo     <- mkFIFOF;
    FIFOF#(DmaRequest)  reqOutFifo       <- mkFIFOF;
    FIFOF#(DmaRequest)  firstReqPipeFifo <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));

    FIFOF#(DmaExtendRequest) reqInFifo        <- mkFIFOF;
    FIFOF#(DmaExtendRequest) inputReqPipeFifo <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));

    StreamSplit firstChunkSplitor <- mkStreamSplit;

    Reg#(DmaMemAddr)       tlpMaxSizeReg      <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidthReg <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   
    Reg#(DataBeats)        tlpMaxBeatsReg     <- mkReg(fromInteger(valueOf(TDiv#(DEFAULT_TLP_SIZE, BYTE_EN_WIDTH))));

    Reg#(Bool)      isInProcReg <- mkReg(False);
    Reg#(DataBeats) beatsReg    <- mkReg(0);

    Reg#(DmaMemAddr) nextStartAddrReg <- mkReg(0);
    Reg#(DmaMemAddr) remainLenReg     <- mkReg(0);
    

    function Bool hasBoundary(DmaExtendRequest request);
        let highIdx = request.endAddr >> tlpMaxSizeWidthReg;
        let lowIdx = request.startAddr >> tlpMaxSizeWidthReg;
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaExtendRequest request);
        // MPS - startAddr % MPS, MPS means MRRS when the module is set to RX mode
        DmaMemAddr remainderOfMps = zeroExtend(PcieTlpMaxMaxPayloadSize'(request.startAddr[tlpMaxSizeWidthReg-1:0]));
        DmaMemAddr offsetOfMps = tlpMaxSizeReg - remainderOfMps;    
        return offsetOfMps;
    endfunction

    // Pipeline stage 1, calculate the first chunkLen which may be smaller than MPS
    rule getfirstChunkLen;
        // If is the first beat of a new request, get firstChunkLen and pipe into the splitor
        if (!isInProcReg) begin
            let request = reqInFifo.first;
            reqInFifo.deq;
            let stream = dataInFifo.first;
            dataInFifo.deq;
            let offset = getOffset(request);
            let firstLen = (request.length > tlpMaxSizeReg) ? tlpMaxSizeReg : request.length;
            let firstChunkLen = hasBoundary(request) ? offset : firstLen;
            // $display($time, "ns SIM INFO @ mkChunkSplit: get first chunkLen, offset %d, remainder %d", offset, PcieTlpMaxMaxPayloadSize'(request.startAddr[tlpMaxSizeWidthReg-1:0]));
            firstChunkSplitor.splitLocationFifoIn.enq(unpack(truncate(firstChunkLen)));
            let firstReq = DmaRequest {
                startAddr : request.startAddr,
                length    : firstChunkLen,
                isWrite   : True
            };
            firstReqPipeFifo.enq(firstReq);
            firstChunkSplitor.inputStreamFifoIn.enq(stream);
            inputReqPipeFifo.enq(request);
            isInProcReg <= !stream.isLast;
        end
        // If is the remain beats of the request, continue pipe into the splitor
        else begin
            let stream = dataInFifo.first;
            dataInFifo.deq;
            firstChunkSplitor.inputStreamFifoIn.enq(stream);
            isInProcReg <= !stream.isLast;
        end 
    endrule

    // Pipeline stage 2: use StreamUtils::StreamSplit to split the input datastream to the firstChunk and the remain chunks
    // In StreamUtils::StreamSplit firstChunkSplitor

    // Pipeline stage 3, set isFirst/isLast accroding to MaxPayloadSize, i.e. split the remain chunks
    rule splitToMps;
        let stream = firstChunkSplitor.outputStreamFifoOut.first;
        firstChunkSplitor.outputStreamFifoOut.deq;
        // End of a TLP, reset beatsReg and tag isLast=True
        if (stream.isLast || beatsReg == tlpMaxBeatsReg - 1) begin
            stream.isLast = True;
            beatsReg <= 0;
        end
        else begin
            beatsReg <= beatsReg + 1;
        end
        // Start of a TLP, get Req Infos and tag isFirst=True
        if (beatsReg == 0) begin
            // $display($time, "ns SIM INFO @ mkChunkSplit: start a new chunk, next addr %d, remainBytesLen %d", nextStartAddrReg, remainLenReg);
            stream.isFirst = True;
            // The first TLP of chunks
            if (firstReqPipeFifo.notEmpty) begin
                let chunkReq = firstReqPipeFifo.first;
                let oriReq = inputReqPipeFifo.first;
                firstReqPipeFifo.deq;
                inputReqPipeFifo.deq;
                if (chunkReq.length == oriReq.length) begin
                    nextStartAddrReg <= 0;
                    remainLenReg     <= 0;
                end
                else begin
                    nextStartAddrReg <= oriReq.startAddr + chunkReq.length;
                    remainLenReg     <= oriReq.length - chunkReq.length;
                end
                reqOutFifo.enq(chunkReq);
            end
            // The following chunks
            else begin  
                let chunkReq = DmaRequest {
                    startAddr: nextStartAddrReg,
                    length   : tlpMaxSizeReg,
                    isWrite  : True
                };
                if (remainLenReg == 0) begin
                    // Do nothing
                end
                else if (remainLenReg <= tlpMaxSizeReg) begin
                    nextStartAddrReg <= 0;
                    remainLenReg     <= 0;
                    chunkReq.length = remainLenReg;
                    reqOutFifo.enq(chunkReq);
                end
                else begin
                    nextStartAddrReg <= nextStartAddrReg + tlpMaxSizeReg;
                    remainLenReg     <= remainLenReg - tlpMaxSizeReg;
                    reqOutFifo.enq(chunkReq);
                end
            end
        end
        
        chunkOutFifo.enq(stream);
    endrule

    interface dataFifoIn = convertFifoToFifoIn(dataInFifo);
    interface reqFifoIn  = convertFifoToFifoIn(reqInFifo);

    interface chunkDataFifoOut = convertFifoToFifoOut(chunkOutFifo);
    interface chunkReqFifoOut  = convertFifoToFifoOut(reqOutFifo);

    interface Put setTlpMaxSize;
        method Action put (PcieTlpSizeSetting tlpSizeSetting);
            let setting = tlpSizeSetting;
            setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1] = (direction == DMA_TX) ? 0 : setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1];
            DmaMemAddr defaultTlpMaxSize = fromInteger(valueOf(DEFAULT_TLP_SIZE));
            tlpMaxSizeReg <= DmaMemAddr'(defaultTlpMaxSize << setting);
            PcieTlpSizeWidth defaultTlpMaxSizeWidth = fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH));
            tlpMaxSizeWidthReg <= PcieTlpSizeWidth'(defaultTlpMaxSizeWidth + zeroExtend(setting));
            // BeatsNum = (MaxPayloadSize + DescriptorSize) / BytesPerBeat
            tlpMaxBeatsReg <= truncate(DmaMemAddr'(defaultTlpMaxSize << setting) >> valueOf(BYTE_EN_WIDTH));
        endmethod
    endinterface
endmodule

// Generate RequesterRequest descriptor 
interface RqDescriptorGenerator;
    interface FifoIn#(DmaExtendRequest) exReqFifoIn;
    interface FifoOut#(DataStream)      descFifoOut;
    interface FifoOut#(SideBandByteEn)  byteEnFifoOut;
endinterface

module mkRqDescriptorGenerator#(Bool isWrite)(RqDescriptorGenerator);
    FIFOF#(DmaExtendRequest) exReqInFifo <- mkFIFOF;
    FIFOF#(DataStream)       descOutFifo <- mkFIFOF;
    FIFOF#(SideBandByteEn)   byteEnOutFifo <- mkFIFOF;

    rule genRqDesc;
        let exReq = exReqInFifo.first;
        exReqInFifo.deq;
        let endOffset = byteModDWord(exReq.endAddr); 
        DwordCount dwCnt = truncate((exReq.endAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)) - (exReq.startAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH))) + 1;
        dwCnt = (exReq.length == 0) ? 1 : dwCnt;
        DataBytePtr bytePtr = fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH)));
        let descriptor  = PcieRequesterRequestDescriptor {
                forceECRC       : False,
                attributes      : 0,
                trafficClass    : 0,
                requesterIdEn   : False,
                completerId     : 0,
                tag             : exReq.tag,
                requesterId     : 0,
                isPoisoned      : False,
                reqType         : isWrite ? fromInteger(valueOf(MEM_WRITE_REQ)) : fromInteger(valueOf(MEM_READ_REQ)),
                dwordCnt        : dwCnt,
                address         : truncate(exReq.startAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)),
                addrType        : fromInteger(valueOf(TRANSLATED_ADDR))
            };
        let stream = DataStream {
            data    : zeroExtend(pack(descriptor)),
            byteEn  : convertBytePtr2ByteEn(bytePtr),
            isFirst : True,
            isLast  : True
        };
        descOutFifo.enq(stream);
        let startAddrOffset = byteModDWord(exReq.startAddr);
        let endAddrOffset = byteModDWord(exReq.endAddr);
        let firstByteEn = convertDWordOffset2FirstByteEn(startAddrOffset);
        let lastByteEn = convertDWordOffset2LastByteEn(endAddrOffset);
        if (exReq.length <= fromInteger(valueOf(DWORD_BYTES))) begin
            firstByteEn = firstByteEn & lastByteEn;
            lastByteEn = 0;
        end
        byteEnOutFifo.enq(tuple2(firstByteEn, lastByteEn));
        // $display($time, "ns SIM INFO @ mkRqDescriptorGenerator: generate, dwcnt %d, start:%d, end:%d, byteCnt:%d ", dwCnt, exReq.startAddr, exReq.endAddr, exReq.length);
    endrule

    interface exReqFifoIn = convertFifoToFifoIn(exReqInFifo);
    interface descFifoOut = convertFifoToFifoOut(descOutFifo);
    interface byteEnFifoOut = convertFifoToFifoOut(byteEnOutFifo);
endmodule

