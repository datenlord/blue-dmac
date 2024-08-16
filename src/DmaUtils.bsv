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
typedef TAdd#(1, TLog#(DEFAULT_TLP_SIZE))   DEFAULT_TLP_SIZE_WIDTH;

typedef 3                                   PCIE_TLP_SIZE_SETTING_WIDTH;
typedef Bit#(PCIE_TLP_SIZE_SETTING_WIDTH)   PcieTlpSizeSetting;      

typedef TAdd#(1, TLog#(TDiv#(BUS_BOUNDARY, BYTE_EN_WIDTH))) DATA_BEATS_WIDTH;
typedef Bit#(DATA_BEATS_WIDTH)                              DataBeats;

typedef struct {
    DmaRequest dmaRequest;
    DmaMemAddr firstChunkLen;
} ChunkRequestFrame deriving(Bits, Eq);                     

// Split the input DmaRequest Info MRRS aligned chunkReqs
interface ChunkCompute;
    interface FifoIn#(DmaRequest)  dmaRequestFifoIn;
    interface FifoOut#(DmaRequest) chunkRequestFifoOut;
    interface Put#(PcieTlpSizeSetting)  setTlpMaxSize;
endinterface 

module mkChunkComputer (TRXDirection direction, ChunkCompute ifc);

    FIFOF#(DmaRequest)   inputFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)   outputFifo <- mkFIFOF;
    FIFOF#(ChunkRequestFrame) splitFifo  <- mkFIFOF;

    Reg#(DmaMemAddr) newChunkPtrReg      <- mkReg(0);
    Reg#(DmaMemAddr) totalLenRemainReg   <- mkReg(0);
    Reg#(Bool)       isSplittingReg      <- mkReg(False);
    
    Reg#(DmaMemAddr)       tlpMaxSize      <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidth <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   

    function Bool hasBoundary(DmaRequest request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaRequest request);
        // MPS - startAddr % MPS, MPS means MRRS when the module is set to RX mode
        DmaMemAddr remainderOfMps = zeroExtend(PcieTlpMaxMaxPayloadSize'(request.startAddr[tlpMaxSizeWidth-1:0]));
        DmaMemAddr offsetOfMps = tlpMaxSize - remainderOfMps;    
        return offsetOfMps;
    endfunction

    rule getfirstChunkLen;
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffset(request);
        let firstLen = (request.length > tlpMaxSize) ? tlpMaxSize : request.length;
        splitFifo.enq(ChunkRequestFrame {
            dmaRequest: request,
            firstChunkLen: hasBoundary(request) ? offset : firstLen
        });
    endrule

    rule execChunkCompute;
        let splitRequest = splitFifo.first;
        if (isSplittingReg) begin   // !isFirst
            if (totalLenRemainReg <= tlpMaxSize) begin 
                isSplittingReg <= False; 
                outputFifo.enq(DmaRequest {
                    startAddr : newChunkPtrReg,
                    length    : totalLenRemainReg,
                    isWrite   : False
                });
                splitFifo.deq;
                totalLenRemainReg <= 0;
            end 
            else begin
                isSplittingReg <= True;
                outputFifo.enq(DmaRequest {
                    startAddr : newChunkPtrReg,
                    length    : tlpMaxSize,
                    isWrite   : False
                });
                newChunkPtrReg <= newChunkPtrReg + tlpMaxSize;
                totalLenRemainReg <= totalLenRemainReg - tlpMaxSize;
            end
        end 
        else begin   // isFirst
            let remainderLength = splitRequest.dmaRequest.length - splitRequest.firstChunkLen;
            Bool isSplittingNextCycle = (remainderLength > 0);
            isSplittingReg <= isSplittingNextCycle;
            outputFifo.enq(DmaRequest {
                startAddr : splitRequest.dmaRequest.startAddr,
                length    : splitRequest.firstChunkLen,
                isWrite   : False
            }); 
            if (!isSplittingNextCycle) begin 
                splitFifo.deq; 
            end
            newChunkPtrReg <= splitRequest.dmaRequest.startAddr + splitRequest.firstChunkLen;
            totalLenRemainReg <= remainderLength;
        end
    endrule

    interface  dmaRequestFifoIn = convertFifoToFifoIn(inputFifo);
    interface  chunkRequestFifoOut = convertFifoToFifoOut(outputFifo);

    interface Put setTlpMaxSize;
        method Action put (PcieTlpSizeSetting tlpSizeSetting);
            let setting = tlpSizeSetting;
            setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1] = (direction == DMA_TX) ? 0 : setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1];
            DmaMemAddr defaultTlpMaxSize = fromInteger(valueOf(DEFAULT_TLP_SIZE));
            tlpMaxSize <= DmaMemAddr'(defaultTlpMaxSize << setting);
            PcieTlpSizeWidth defaultTlpMaxSizeWidth = fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH));
            tlpMaxSizeWidth <= PcieTlpSizeWidth'(defaultTlpMaxSizeWidth + zeroExtend(setting));
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
    interface FifoIn#(DmaRequest)       reqFifoIn;
    interface FifoOut#(DataStream)      chunkDataFifoOut;
    interface FifoOut#(DmaRequest)      chunkReqFifoOut;
    interface Put#(PcieTlpSizeSetting)  setTlpMaxSize;
endinterface

module mkChunkSplit(TRXDirection direction, ChunkSplit ifc);
    FIFOF#(DataStream)  dataInFifo       <- mkFIFOF;
    FIFOF#(DmaRequest)  reqInFifo        <- mkFIFOF;
    FIFOF#(DataStream)  chunkOutFifo     <- mkFIFOF;
    FIFOF#(DmaRequest)  reqOutFifo       <- mkFIFOF;
    FIFOF#(DmaRequest)  firstReqPipeFifo <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));
    FIFOF#(DmaRequest)  inputReqPipeFifo <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));

    StreamSplit firstChunkSplitor <- mkStreamSplit;

    Reg#(DmaMemAddr)       tlpMaxSizeReg      <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidthReg <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   
    Reg#(DataBeats)        tlpMaxBeatsReg     <- mkReg(fromInteger(valueOf(TDiv#(DEFAULT_TLP_SIZE, BYTE_EN_WIDTH))));

    Reg#(Bool)      isInProcReg <- mkReg(False);
    Reg#(DataBeats) beatsReg    <- mkReg(0);

    Reg#(DmaMemAddr) nextStartAddrReg <- mkReg(0);
    Reg#(DmaMemAddr) remainLenReg     <- mkReg(0);
    

    function Bool hasBoundary(DmaRequest request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaRequest request);
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
            firstChunkSplitor.splitLocationFifoIn.enq(unpack(truncate(firstChunkLen)));
            let firstReq = DmaRequest {
                startAddr : request.startAddr,
                length    : firstChunkLen,
                isWrite   : request.isWrite
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
        if (stream.isLast || beatsReg == tlpMaxBeatsReg) begin
            stream.isLast = True;
            beatsReg <= 0;
        end
        else begin
            beatsReg <= beatsReg + 1;
        end
        // Start of a TLP, get Req Infos and tag isFirst=True
        if (beatsReg == 0) begin
            stream.isFirst = True;
            // The first TLP of chunks
            if (firstReqPipeFifo.notEmpty) begin
                let chunkReq = firstReqPipeFifo.first;
                let oriReq = inputReqPipeFifo.first;
                firstReqPipeFifo.deq;
                nextStartAddrReg <= oriReq.startAddr + chunkReq.length;
                remainLenReg     <= oriReq.length - chunkReq.length;
                reqOutFifo.enq(chunkReq);
            end
            // The following chunks
            else begin  
                if (remainLenReg == 0) begin
                    // Do nothing
                end
                else if (remainLenReg <= tlpMaxSizeReg) begin
                    nextStartAddrReg <= 0;
                    remainLenReg     <= 0;
                    let chunkReq = DmaRequest {
                        startAddr: nextStartAddrReg,
                        length   : remainLenReg,
                        isWrite  : True
                    };
                    reqOutFifo.enq(chunkReq);
                end
                else begin
                    nextStartAddrReg <= nextStartAddrReg + tlpMaxSizeReg;
                    remainLenReg     <= remainLenReg - tlpMaxSizeReg;
                    let chunkReq = DmaRequest {
                        startAddr: nextStartAddrReg,
                        length   : tlpMaxSizeReg,
                        isWrite  : True
                    };
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
endinterface

module mkRqDescriptorGenerator#(Bool isWrite)(RqDescriptorGenerator);
    FIFOF#(DmaExtendRequest) exReqInFifo <- mkFIFOF;
    FIFOF#(DataStream)       descOutFifo <- mkFIFOF;

    rule genRqDesc;
        let exReq = exReqInFifo.first;
        exReqInFifo.deq;
        let endOffset = byteModDWord(exReq.endAddr); 
        DwordCount dwCnt = truncate((exReq.endAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)) - (exReq.startAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)));
        dwCnt = (endOffset == 0) ? dwCnt : dwCnt + 1;
        dwCnt = (exReq.length == 0) ? 1 : dwCnt;
        DataBytePtr bytePtr = fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH)));
        let descriptor  = PcieRequesterRequestDescriptor {
                forceECRC       : False,
                attributes      : 0,
                trafficClass    : 0,
                requesterIdEn   : False,
                completerId     : 0,
                tag             : 0,
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
    endrule

    interface exReqFifoIn = convertFifoToFifoIn(exReqInFifo);
    interface descFifoOut = convertFifoToFifoOut(descOutFifo);
endmodule

