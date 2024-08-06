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


typedef 4096                                BUS_BOUNDARY;
typedef TAdd#(1, TLog#(BUS_BOUNDARY))       BUS_BOUNDARY_WIDTH;

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
                    startAddr: newChunkPtrReg,
                    length: totalLenRemainReg
                });
                splitFifo.deq;
                totalLenRemainReg <= 0;
            end 
            else begin
                isSplittingReg <= True;
                outputFifo.enq(DmaRequest {
                    startAddr: newChunkPtrReg,
                    length: tlpMaxSize
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
                startAddr: splitRequest.dmaRequest.startAddr,
                length: splitRequest.firstChunkLen
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
                length    : firstChunkLen
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
                        length   : remainLenReg
                    };
                    reqOutFifo.enq(chunkReq);
                end
                else begin
                    nextStartAddrReg <= nextStartAddrReg + tlpMaxSizeReg;
                    remainLenReg     <= remainLenReg - tlpMaxSizeReg;
                    let chunkReq = DmaRequest {
                        startAddr: nextStartAddrReg,
                        length   : tlpMaxSizeReg
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

typedef 2'b00 NO_TLP_IN_THIS_BEAT;
typedef 2'b01 SINGLE_TLP_IN_THIS_BEAT;
typedef 2'b11 DOUBLE_TLP_IN_THIS_BEAT;

typedef 2'b00 ISSOP_LANE_0;
typedef 2'b10 ISSOP_LANE_32;

typedef 3 BYTEEN_INFIFO_DEPTH;

// Convert 2 DataStream input to 1 PcieAxiStream output
// - The axistream is in straddle mode which means tKeep and tLast are ignored
// - The core use isSop and isEop to location Tlp and allow 2 Tlp in one beat
// - The input dataStream should be added Descriptor and aligned to DW already
interface ConvertDataStreamsToStraddleAxis;
    interface FifoIn#(DataStream)       dataAFifoIn;
    interface FifoIn#(SideBandByteEn)   byteEnAFifoIn;
    interface FifoIn#(DataStream)       dataBFifoIn;
    interface FifoIn#(SideBandByteEn)   byteEnBFifoIn;
    interface FifoOut#(ReqReqAxiStream) axiStreamFifoOut;
endinterface

module mkConvertDataStreamsToStraddleAxis(ConvertDataStreamsToStraddleAxis);
    FIFOF#(SideBandByteEn)   byteEnAFifo <- mkSizedFIFOF(valueOf(BYTEEN_INFIFO_DEPTH));
    FIFOF#(SideBandByteEn)   byteEnBFifo <- mkSizedFIFOF(valueOf(BYTEEN_INFIFO_DEPTH));

    StreamShiftComplex shiftA <- mkStreamShiftComplex(fromInteger(valueOf(STRADDLE_THRESH_BYTE_WIDTH)));
    StreamShiftComplex shiftB <- mkStreamShiftComplex(fromInteger(valueOf(STRADDLE_THRESH_BYTE_WIDTH)));

    FIFOF#(ReqReqAxiStream) axiStreamOutFifo <- mkFIFOF;

    Reg#(Bool) isInStreamAReg <- mkReg(False);
    Reg#(Bool) isInStreamBReg <- mkReg(False);
    Reg#(Bool) isInShiftAReg <- mkReg(False);
    Reg#(Bool) isInShiftBReg <- mkReg(False);
    Reg#(Bool) roundRobinReg <- mkReg(False);

    function Bool hasStraddleSpace(DataStream sdStream);
        return !unpack(sdStream.byteEn[valueOf(STRADDLE_THRESH_BYTE_WIDTH)]);
    endfunction

    function PcieRequesterRequestSideBandFrame genRQSideBand(
        PcieTlpCtlIsEopCommon isEop, PcieTlpCtlIsSopCommon isSop, SideBandByteEn byteEnA, SideBandByteEn byteEnB
        );
        let {firstByteEnA, lastByteEnA} = byteEnA;
        let {firstByteEnB, lastByteEnB} = byteEnB;
        let sideBand = PcieRequesterRequestSideBandFrame {
            // Do not use parity check in the core
            parity              : 0,
            // Do not support progress track
            seqNum1             : 0,
            seqNum0             : 0,
            //TODO: Do not support Transaction Processing Hint now, maybe we need TPH for better performance
            tphSteeringTag      : 0,
            tphIndirectTagEn    : 0,
            tphType             : 0,
            tphPresent          : 0,
            // Do not support discontinue
            discontinue         : False,
            // Indicates end of the tlp
            isEop               : isEop,
            // Indicates starts of a new tlp
            isSop               : isSop,
            // Disable when use DWord-aligned Mode
            addrOffset          : 0,
            // Indicates byte enable in the first/last DWord
            lastByteEn          : {pack(lastByteEnB), pack(lastByteEnA)},
            firstByteEn         : {pack(firstByteEnB), pack(firstByteEnA)}
        };
        return sideBand;
    endfunction

    // Pipeline stage 1: get the shift datastream

    // Pipeline Stage 2: get the axiStream data
    rule genStraddlePcie;
        DataStream sendingStream = getEmptyStream;
        DataStream pendingStream = getEmptyStream;
        Bool isSendingA = True;

        // In streamA sending epoch, waiting streamA until isLast
        if (isInStreamAReg) begin
            let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
            sendingStream = isInShiftAReg ? shiftStreamA : oriStreamA;
            shiftA.streamFifoOut.deq;
            isSendingA = True;
            if (shiftB.streamFifoOut.notEmpty && sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                pendingStream = shiftStreamB;
                shiftB.streamFifoOut.deq;
            end
        end
        // In streamB sendging epoch, waiting streamB until isLast
        else if (isInStreamBReg) begin
            let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
            sendingStream = isInShiftBReg ? shiftStreamB : oriStreamB;
            shiftB.streamFifoOut.deq;
            isSendingA = False;
            if (shiftA.streamFifoOut.notEmpty && sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                pendingStream = shiftStreamA;
                shiftA.streamFifoOut.deq;
            end
        end
        // In Idle, choose one stream to enter new epoch
        else begin
            if (shiftA.streamFifoOut.notEmpty && shiftB.streamFifoOut.notEmpty) begin
                roundRobinReg <= !roundRobinReg;
                if (roundRobinReg) begin
                    let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                    sendingStream = oriStreamA;
                    shiftA.streamFifoOut.deq;
                    isSendingA = True;
                    if (sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                        let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                        pendingStream = shiftStreamB;
                        shiftB.streamFifoOut.deq;
                    end
                end
                else begin
                    let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                    sendingStream = oriStreamB;
                    shiftB.streamFifoOut.deq;
                    isSendingA = False;
                    if (sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                        let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                        pendingStream = shiftStreamA;
                        shiftA.streamFifoOut.deq;
                    end
                end
            end
            else if (shiftA.streamFifoOut.notEmpty) begin
                let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                sendingStream = oriStreamA;
                shiftA.streamFifoOut.deq;
                isSendingA = True;
                roundRobinReg  <= False;
            end
            else if (shiftB.streamFifoOut.notEmpty) begin 
                let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                sendingStream = oriStreamB;
                shiftB.streamFifoOut.deq;
                isSendingA = False;
                roundRobinReg  <= True;
            end
            else begin
                // Do nothing
            end
        end

        if (!isByteEnZero(sendingStream.byteEn)) begin
            // Change the registers and generate PcieAxiStream
            let sideBandByteEnA = tuple2(0, 0);
            let sideBandByteEnB = tuple2(0, 0);
            if (isSendingA) begin
                isInStreamAReg <= !sendingStream.isLast;
                isInShiftAReg  <= sendingStream.isLast ? False : isInShiftAReg;
                if (sendingStream.isFirst) begin
                    sideBandByteEnA = byteEnAFifo.first;
                    byteEnAFifo.deq;
                end
                if (sendingStream.isLast && hasStraddleSpace(sendingStream) && !isByteEnZero(pendingStream.byteEn)) begin
                    isInStreamBReg <= !pendingStream.isLast;
                    isInShiftBReg  <= !pendingStream.isLast;
                    sideBandByteEnB = byteEnBFifo.first;
                    byteEnBFifo.deq;
                end
            end 
            else begin
                isInStreamBReg <= !sendingStream.isLast;
                isInShiftBReg  <= sendingStream.isLast ? False : isInShiftBReg;
                if (sendingStream.isFirst) begin
                    sideBandByteEnB = byteEnBFifo.first;
                    byteEnBFifo.deq;
                end
                if (sendingStream.isLast && hasStraddleSpace(sendingStream) && !isByteEnZero(pendingStream.byteEn)) begin
                    isInStreamAReg <= !pendingStream.isLast;
                    isInShiftAReg  <= !pendingStream.isLast;
                    sideBandByteEnA = byteEnAFifo.first;
                    byteEnAFifo.deq;
                end
            end

            let isSop = PcieTlpCtlIsSopCommon {
                isSopPtrs  : replicate(0),
                isSop      : 0
            };
            let isEop = PcieTlpCtlIsEopCommon {
                isEopPtrs  : replicate(0),
                isEop      : 0
            };
            
            if (sendingStream.isFirst && pendingStream.isFirst) begin
                isSop.isSop = fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT));
                isSop.isSopPtrs[0] = fromInteger(valueOf(ISSOP_LANE_0));
                isSop.isSopPtrs[1] = fromInteger(valueOf(ISSOP_LANE_32));
            end
            else if (sendingStream.isFirst || pendingStream.isFirst) begin
                isSop.isSop = fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT));
                isSop.isSopPtrs[0] = fromInteger(valueOf(ISSOP_LANE_0));
            end
            if (pendingStream.isLast && !isByteEnZero(pendingStream.byteEn)) begin
                isEop.isEop = fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT));
                isEop.isEopPtrs[0] = truncate(convertByteEn2DwordPtr(sendingStream.byteEn));
                isEop.isEopPtrs[1] = fromInteger(valueOf(STRADDLE_THRESH_DWORD_WIDTH)) + truncate(convertByteEn2DwordPtr(pendingStream.byteEn));
            end
            else if (sendingStream.isLast) begin
                isEop.isEop = fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT));
                isEop.isEopPtrs[0] = truncate(convertByteEn2DwordPtr(sendingStream.byteEn));
            end
            
            let sideBand = genRQSideBand(isEop, isSop, sideBandByteEnA, sideBandByteEnB);
            let axiStream = ReqReqAxiStream {
                tData  : sendingStream.data | pendingStream.data,
                tKeep  : -1,
                tLast  : False,
                tUser  : pack(sideBand)
            };
            axiStreamOutFifo.enq(axiStream);
        end
    endrule

    interface dataAFifoIn      = shiftA.streamFifoIn;
    interface byteEnAFifoIn    = convertFifoToFifoIn(byteEnAFifo);
    interface dataBFifoIn      = shiftB.streamFifoIn;
    interface byteEnBFifoIn    = convertFifoToFifoIn(byteEnBFifo);
    interface axiStreamFifoOut = convertFifoToFifoOut(axiStreamOutFifo);
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

// Core path of a single stream, from (DataStream, DmaRequest) ==> (DataStream, SideBandByteEn)
// split to chunks, align to DWord and add descriptor at the first
interface RequesterRequestCore;
    interface FifoIn#(DataStream)      dataFifoIn;
    interface FifoIn#(DmaRequest)      wrReqFifoIn;
    interface FifoIn#(DmaRequest)      rdReqFifoIn;
    interface FifoOut#(DataStream)     dataFifoOut;
    interface FifoOut#(SideBandByteEn) byteEnFifoOut;
    interface Get#(Bool)               isWriteDone;
endinterface

module mkRequesterRequestCore(RequesterRequestCore);
    FIFOF#(DataStream)     dataInFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)     wrReqInFifo <- mkFIFOF;
    FIFOF#(DmaRequest)     rdReqInFifo <- mkFIFOF;
    FIFOF#(DataStream)     dataOutFifo <- mkFIFOF;
    FIFOF#(SideBandByteEn) byteEnOutFifo <- mkFIFOF;

    ChunkSplit chunkSplit <- mkChunkSplit(DMA_TX);
    StreamShiftAlignToDw streamAlign <- mkStreamShiftAlignToDw(fromInteger(valueOf(TDiv#(DES_RQ_DESCRIPTOR_WIDTH, BYTE_WIDTH))));
    RqDescriptorGenerator rqDescGenerator <- mkRqDescriptorGenerator(True);

    // Pipeline stage 1: split the whole write request to chunks, latency = 3
    rule splitToChunks;
        let wrStream = dataInFifo.first;
        if (wrStream.isFirst && wrReqInFifo.notEmpty) begin
            wrReqInFifo.deq;
            chunkSplit.reqFifoIn.enq(wrReqInFifo.first);
            dataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrStream);
        end
        else if (!wrStream.isFirst) begin
            dataInFifo.deq;
            chunkSplit.dataFifoIn.enq(wrStream);
        end
    endrule

    // Pipeline stage 2: shift the datastream for descriptor adding and dw alignment
    rule shiftToAlignment;
        if (chunkSplit.chunkReqFifoOut.notEmpty) begin
            let chunkReq = chunkSplit.chunkReqFifoOut.first;
            chunkSplit.chunkReqFifoOut.deq;
            let endAddr = chunkReq.startAddr + chunkReq.length;
            let exReq = DmaExtendRequest {
                startAddr:  chunkReq.startAddr,
                endAddr  :  endAddr,
                length   :  chunkReq.length
            };
            streamAlign.reqFifoIn.enq(exReq);
            rqDescGenerator.exReqFifoIn.enq(exReq);
        end
        if (chunkSplit.chunkDataFifoOut.notEmpty) begin
            let chunkDataStream = chunkSplit.chunkDataFifoOut.first;
            chunkSplit.chunkDataFifoOut.deq;
            streamAlign.dataFifoIn.enq(chunkDataStream);
        end
    endrule

    // Pipeline stage 3: Add descriptor and add to the axis convert module
    rule addDescriptorToAxis;
        if (streamAlign.byteEnFifoOut.notEmpty) begin
            let sideBandByteEn = streamAlign.byteEnFifoOut.first;
            streamAlign.byteEnFifoOut.deq;
            byteEnOutFifo.enq(sideBandByteEn);
        end
        if (streamAlign.dataFifoOut.notEmpty) begin
            let stream = streamAlign.dataFifoOut.first;
            streamAlign.dataFifoOut.deq;
            if (stream.isFirst) begin
                let descStream = rqDescGenerator.descFifoOut.first;
                rqDescGenerator.descFifoOut.deq;
                stream.data = stream.data | descStream.data;
                stream.byteEn = stream.byteEn | descStream.byteEn;
            end
            dataOutFifo.enq(stream);
        end
    endrule

    interface dataFifoIn    = convertFifoToFifoIn(dataInFifo);
    interface wrReqFifoIn   = convertFifoToFifoIn(wrReqInFifo);
    interface rdReqFifoIn   = convertFifoToFifoIn(rdReqInFifo);
    interface dataFifoOut   = convertFifoToFifoOut(dataOutFifo);
    interface byteEnFifoOut = convertFifoToFifoOut(byteEnOutFifo);

    // TODO: how to give the 
    interface Get isWriteDone;
        method ActionValue#(Bool) get();
            return True;
        endmethod
    endinterface
endmodule
