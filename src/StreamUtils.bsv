import Vector::*;
import FIFOF::*;
import GetPut::*;
import SemiFifo::*;

import PrimUtils::*;
import DmaTypes::*;
import PcieAxiStreamTypes::*;

typedef 32 STREAM_SIZE_WIDTH;
typedef UInt#(STREAM_SIZE_WIDTH) StreamSize;
typedef Bit#(TAdd#(1, TLog#(STREAM_SIZE_WIDTH))) StreamSizeBitPtr;

typedef struct {
    DataStream stream;
    DataBytePtr bytePtr;
} StreamWithPtr deriving(Bits, Bounded, Eq, FShow);

interface StreamPipe;
    interface FifoIn#(DataStream)  streamFifoIn;
    interface FifoOut#(DataStream) streamFifoOut;
endinterface

interface StreamSplit;
    interface FifoIn#(DataStream)  inputStreamFifoIn;
    interface FifoIn#(StreamSize)  splitLocationFifoIn;
    interface FifoOut#(DataStream) outputStreamFifoOut;
endinterface

function Bool isByteEnZero(ByteEn byteEn);
    return !unpack(byteEn[0]);
endfunction

function Bool isByteEnFull(ByteEn byteEn);
    return unpack(byteEn[valueOf(BYTE_EN_WIDTH)-1]);
endfunction

function DataStream getEmptyStream ();
    return DataStream {
        data: 0,
        byteEn: 0,
        isFirst: False,
        isLast: True
    };
endfunction

function StreamWithPtr getEmptyStreamWithPtr ();
    return StreamWithPtr {
        stream : getEmptyStream,
        bytePtr: 0
    };
endfunction

function DataBitPtr getMaxBitPtr ();
    return fromInteger(valueOf(DATA_WIDTH));
endfunction

function DataBytePtr getMaxBytePtr ();
    return fromInteger(valueOf(BYTE_EN_WIDTH));
endfunction

// Concat two DataStream frames into one. StreamA.isLast must be True, otherwise the function will return a empty frame to end the stream.
function Tuple2#(StreamWithPtr, StreamWithPtr) getConcatStream (StreamWithPtr streamA, StreamWithPtr streamB);
    Bool isCallLegally = (streamA.stream.isLast && streamA.bytePtr <= getMaxBytePtr && streamA.bytePtr >= 0);
    DataBitPtr bitPtrA = zeroExtend(streamA.bytePtr) << fromInteger(valueOf(BYTE_WIDTH_WIDTH));

    // Fill the low PtrA bytes by streamA data
    Data   concatDataA   = streamA.stream.data;
    ByteEn concatByteEnA = streamA.stream.byteEn;

    // Fill the high bytes by streamB data
    Data   concatDataB   = streamB.stream.data   << bitPtrA;
    ByteEn concatByteEnB = streamB.stream.byteEn << streamA.bytePtr;
    Data   concatData    = concatDataA   | concatDataB;
    ByteEn concatByteEn  = concatByteEnA | concatByteEnB;

    // Get the remain bytes of streamB data
    DataBitPtr  resBitPtr    = getMaxBitPtr  - bitPtrA;
    DataBytePtr resBytePtr   = getMaxBytePtr - streamA.bytePtr;
    Data        remainData   = streamB.stream.data   >> resBitPtr;
    ByteEn      remainByteEn = streamB.stream.byteEn >> resBytePtr;

    // Get if the concat frame is the last, i.e. can streamB be contained by the residual empty bytes
    Bool        isConcatStreamLast = streamB.stream.isLast;
    DataBytePtr remainBytePtr      = 0;
    DataBytePtr concatStreamPtr    = streamA.bytePtr;
    if (resBytePtr < streamB.bytePtr ) begin    
        isConcatStreamLast = False;
        remainBytePtr      = streamB.bytePtr - resBytePtr;
        concatStreamPtr    = getMaxBytePtr;
    end
    else begin
        concatStreamPtr    = streamA.bytePtr + streamB.bytePtr;
    end

    // package the return concatStream and remainStream
    DataStream concatStream = getEmptyStream;
    DataStream remainStream = getEmptyStream;
    if(isCallLegally) begin
        concatStream = DataStream {
            data   : concatData,
            byteEn : concatByteEn,
            isFirst: streamA.stream.isFirst,
            isLast : isConcatStreamLast
        };
        remainStream = DataStream {
            data   : remainData,
            byteEn : remainByteEn,
            isFirst: False,
            isLast : True
        };
    end
    let concatStreamWithPtr = StreamWithPtr {
        stream : concatStream,
        bytePtr: concatStreamPtr
    };
    let remainStreamWithPtr = StreamWithPtr {
        stream : remainStream,
        bytePtr: remainBytePtr
    };
    return tuple2(concatStreamWithPtr, remainStreamWithPtr);
endfunction

typedef 3 STREAM_SPLIT_LATENCY;

module mkStreamSplit(StreamSplit ifc);

    Reg#(StreamSize) streamByteCntReg <- mkReg(0);

    FIFOF#(StreamSize)    splitLocationFifo <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));
    FIFOF#(DataStream)    inputFifo         <- mkFIFOF;
    FIFOF#(DataStream)    outputFifo        <- mkFIFOF;
    FIFOF#(StreamWithPtr) prepareFifo       <- mkFIFOF;
    FIFOF#(StreamWithPtr) assertFifo        <- mkFIFOF;
    FIFOF#(DataBytePtr)   splitPtrFifo      <- mkSizedFIFOF(valueOf(STREAM_SPLIT_LATENCY));

    Reg#(StreamWithPtr)   remainStreamWpReg <- mkRegU;

    Reg#(Bool) hasRemainReg     <- mkReg(False);
    Reg#(Bool) hasLastRemainReg <- mkReg(False);
    Reg#(Bool) isSplittedReg    <- mkReg(False);
    
    // Pipeline stage 1: get the bytePtr of the input stream frame
    rule prepareStream;
        let stream = inputFifo.first;
        inputFifo.deq;
        StreamWithPtr streamWithPtr = StreamWithPtr {
            stream: stream,
            bytePtr: convertByteEn2BytePtr(stream.byteEn) 
        };
        prepareFifo.enq(streamWithPtr);
    endrule

    // Pipeline stage 2: assert if splitLocation in this beat and calculate the offsetBytePtr
    rule assertSplitStream;
        let stream = prepareFifo.first.stream;
        let bytePtr = prepareFifo.first.bytePtr;       
        prepareFifo.deq; 
        let splitLocation = splitLocationFifo.first;
        if (stream.isLast) begin
            splitLocationFifo.deq;
        end
        DataBytePtr offsetBytePtr = 0;
        let curLocation = unpack(zeroExtend(bytePtr)) + streamByteCntReg;
        if (!isSplittedReg && curLocation >= splitLocation) begin
            offsetBytePtr = truncate(pack(splitLocation - curLocation));
        end
        splitPtrFifo.enq(offsetBytePtr);
        if (offsetBytePtr > 0 && !stream.isLast) begin
            isSplittedReg <= True;
        end 
        else if (stream.isLast) begin
            isSplittedReg <= False;
        end
        streamByteCntReg <= stream.isLast ? 0 : streamByteCntReg + unpack(zeroExtend(bytePtr));
        assertFifo.enq(prepareFifo.first);
    endrule

    // Pipeline stage 3: split the stream frame or output it without modify accroding to offsetBytePtr
    rule execSplitStream;
        // Only output remainStreamReg
        if (hasRemainReg && hasLastRemainReg) begin
            outputFifo.enq(remainStreamWpReg.stream);
            hasRemainReg <= False;
            hasLastRemainReg <= False;
        end
        // not the last remain stream
        else if (assertFifo.notEmpty && splitPtrFifo.notEmpty) begin
            let streamWp = assertFifo.first;
            let offsetBytePtr = splitPtrFifo.first;
            assertFifo.deq;
            splitPtrFifo.deq;
            // split location not in this beat, do nothing
            if (!hasRemainReg && offsetBytePtr == 0) begin
                outputFifo.enq(streamWp.stream);
                hasRemainReg     <= False;
                hasLastRemainReg <= False;
            end
            // split the frame in this cycle to a isLast=True frame and a remain frame
            else if (!hasRemainReg && offsetBytePtr > 0) begin
                DataBitPtr offsetBitPtr = zeroExtend(offsetBytePtr) << valueOf(BYTE_WIDTH_WIDTH);
                let splitStream = DataStream {
                    data: getDataLowBytes(streamWp.stream.data, offsetBytePtr),
                    byteEn: convertBytePtr2ByteEn(offsetBytePtr),
                    isFirst: streamWp.stream.isFirst,
                    isLast: True
                };
                outputFifo.enq(splitStream);
                let remainStream = DataStream {
                    data: streamWp.stream.data >> offsetBitPtr,
                    byteEn: streamWp.stream.byteEn >> offsetBytePtr,
                    isFirst: True,
                    isLast: True
                };
                hasRemainReg      <= True;
                hasLastRemainReg  <= streamWp.stream.isLast;
                remainStreamWpReg <= StreamWithPtr {
                    stream : remainStream,
                    bytePtr: streamWp.bytePtr - offsetBytePtr
                };
            end
            // concat the stream frame with the remainReg
            else begin
                let {concatStreamWp, remainStreamWp} = getConcatStream(remainStreamWpReg, streamWp);
                outputFifo.enq(concatStreamWp.stream);
                hasRemainReg     <= streamWp.stream.isLast ? !isByteEnZero(remainStreamWp.stream.byteEn) : True;
                hasLastRemainReg <= streamWp.stream.isLast;
                remainStreamWpReg <= remainStreamWp;
            end
        end
    endrule

    interface inputStreamFifoIn   = convertFifoToFifoIn(inputFifo);
    interface splitLocationFifoIn = convertFifoToFifoIn(splitLocationFifo);
    interface outputStreamFifoOut = convertFifoToFifoOut(outputFifo);

endmodule

typedef 2 STREAM_SHIFT_LATENCY;

module mkStreamShift#(DataBytePtr offset)(StreamPipe);
    FIFOF#(DataStream) inFifo  <- mkFIFOF;
    FIFOF#(DataStream) outFifo <- mkFIFOF;

    DataBytePtr resByte    = getMaxBytePtr - offset;
    DataBitPtr  offsetBits = zeroExtend(offset) << valueOf(BYTE_WIDTH_WIDTH);
    DataBitPtr  resBits    = getMaxBitPtr - offsetBits;

    Reg#(DataStream) remainStreamReg <- mkReg(getEmptyStream);
    Reg#(Bool)  hasLastRemainReg <- mkReg(False);

    function Bool isShiftStreamLast(DataStream stream);
        Bool isLast = False;
        if (offset > 0 && offset < getMaxBytePtr) begin
            isLast = stream.isLast && !unpack(stream.byteEn[resByte]);
        end
        else if (offset == 0) begin
            isLast = stream.isLast;
        end
        else begin
            isLast = False;
        end
        return isLast;
    endfunction

    rule execShift;
        if (hasLastRemainReg) begin
            outFifo.enq(remainStreamReg);
            hasLastRemainReg <= False;
            remainStreamReg <= getEmptyStream;
        end
        else begin
            let stream = inFifo.first;
            inFifo.deq;
            let shiftStream = DataStream {
                data    : (stream.data << offsetBits) | remainStreamReg.data,
                byteEn  : (stream.byteEn << offset)   | remainStreamReg.byteEn,
                isFirst : stream.isFirst,
                isLast  : isShiftStreamLast(stream)
            };
            let remainStream = DataStream {
                data    : stream.data >> resBits,
                byteEn  : stream.byteEn >> resByte,
                isFirst : False,
                isLast  : True
            };
            outFifo.enq(shiftStream);
            remainStreamReg  <= remainStream;
            hasLastRemainReg <= stream.isLast && !isByteEnZero(remainStream.byteEn);
        end
    endrule

    interface streamFifoIn  = convertFifoToFifoIn(inFifo);
    interface streamFifoOut = convertFifoToFifoOut(outFifo);
endmodule

interface StreamShiftComplex;
    interface FifoIn#(DataStream)  streamFifoIn;
    interface FifoOut#(Tuple2#(DataStream, DataStream)) streamFifoOut;
endinterface

module mkStreamShiftComplex#(DataBytePtr offset)(StreamShiftComplex);
    FIFOF#(DataStream) inFifo  <- mkFIFOF;
    FIFOF#(Tuple2#(DataStream, DataStream)) outFifo <- mkFIFOF;

    DataBytePtr resByte    = getMaxBytePtr - offset;
    DataBitPtr  offsetBits = zeroExtend(offset) << valueOf(BYTE_WIDTH_WIDTH);
    DataBitPtr  resBits    = getMaxBitPtr - offsetBits;

    Reg#(DataStream) remainStreamReg <- mkReg(getEmptyStream);
    Reg#(Bool)  hasLastRemainReg <- mkReg(False);

    function Bool isShiftStreamLast(DataStream stream);
        Bool isLast = False;
        if (offset > 0 && offset < getMaxBytePtr) begin
            isLast = stream.isLast && !unpack(stream.byteEn[resByte]);
        end
        else if (offset == 0) begin
            isLast = stream.isLast;
        end
        else begin
            isLast = False;
        end
        return isLast;
    endfunction

    rule execShift;
        if (hasLastRemainReg) begin
            outFifo.enq(tuple2(getEmptyStream, remainStreamReg));
            hasLastRemainReg <= False;
            remainStreamReg <= getEmptyStream;
        end
        else begin
            let stream = inFifo.first;
            inFifo.deq;
            let shiftStream = DataStream {
                data    : (stream.data << offsetBits) | remainStreamReg.data,
                byteEn  : (stream.byteEn << offset)   | remainStreamReg.byteEn,
                isFirst : stream.isFirst,
                isLast  : isShiftStreamLast(stream)
            };
            let remainStream = DataStream {
                data    : stream.data >> resBits,
                byteEn  : stream.byteEn >> resByte,
                isFirst : False,
                isLast  : True
            };
            outFifo.enq(tuple2(stream, shiftStream));
            remainStreamReg  <= remainStream;
            hasLastRemainReg <= stream.isLast && !isByteEnZero(remainStream.byteEn);
        end
    endrule

    interface streamFifoIn  = convertFifoToFifoIn(inFifo);
    interface streamFifoOut = convertFifoToFifoOut(outFifo);
endmodule

interface StreamShiftAlignToDw;
    interface FifoIn#(DataStream)        dataFifoIn;
    interface FifoIn#(DmaExtendRequest)  reqFifoIn;
    interface FifoOut#(DataStream)       dataFifoOut;
    interface FifoOut#(SideBandByteEn)   byteEnFifoOut;
endinterface

typedef 2 STREAM_ALIGN_DW_LATENCY;

module mkStreamShiftAlignToDw#(DataBytePtr offset)(StreamShiftAlignToDw);
    FIFOF#(DataStream)       dataInFifo     <- mkFIFOF;
    FIFOF#(DmaExtendRequest) reqInFifo      <- mkFIFOF;
    FIFOF#(DataStream)       dataOutFifo    <- mkFIFOF;
    FIFOF#(SideBandByteEn)   byteEnOutFifo  <- mkFIFOF;

    FIFOF#(DataBytePtr)      shiftSetFifo   <- mkSizedFIFOF(valueOf(TMul#(2, STREAM_SHIFT_LATENCY)));

    Vector#(DWORD_BYTES, StreamPipe) shifts = newVector;
    for (DataBytePtr idx = 0; idx < fromInteger(valueOf(DWORD_BYTES)); idx = idx + 1 ) begin
        shifts[idx] <- mkStreamShift(offset + idx);
    end

    rule getOffset;
        let exReq = reqInFifo.first;
        reqInFifo.deq;
        ByteModDWord startAddrOffset = byteModDWord(exReq.startAddr);
        shiftSetFifo.enq(zeroExtend(startAddrOffset));
        ByteModDWord endAddrOffset = byteModDWord(exReq.endAddr);
        let firstByteEn = convertDWordOffset2FirstByteEn(startAddrOffset);
        let lastByteEn  = convertDWordOffset2LastByteEn(endAddrOffset);
        byteEnOutFifo.enq(tuple2(firstByteEn, lastByteEn));
        let stream = dataInFifo.first;
        dataInFifo.deq;
        for (DataBytePtr idx = 0; idx < fromInteger(valueOf(DWORD_BYTES)); idx = idx + 1 ) begin
            shifts[idx].streamFifoIn.enq(stream);
        end
    endrule

    rule getShiftData;
        DataStream stream = getEmptyStream;
        let offset = shiftSetFifo.first;
        for (DataBytePtr idx = 0; idx < fromInteger(valueOf(DWORD_BYTES)); idx = idx + 1 ) begin
            shifts[idx].streamFifoOut.deq;
            if (idx == offset) begin
                stream = shifts[idx].streamFifoOut.first;
            end
        end
        if (stream.isLast) begin
            shiftSetFifo.deq;
        end
        dataOutFifo.enq(stream);
    endrule

    interface dataFifoIn    = convertFifoToFifoIn(dataInFifo);
    interface reqFifoIn     = convertFifoToFifoIn(reqInFifo);
    interface dataFifoOut   = convertFifoToFifoOut(dataOutFifo);
    interface byteEnFifoOut = convertFifoToFifoOut(byteEnOutFifo);
endmodule

typedef 3 STREAM_HEADER_REMOVE_LATENCY;

// Remove the first N Bytes of a stream
module mkStreamHeaderRemove#(DataBytePtr headerLen)(StreamPipe);
    FIFOF#(DataStream) inFifo  <- mkFIFOF;
    FIFOF#(DataStream) outFifo <- mkFIFOF;

    Reg#(DataStream) remainStreamReg  <- mkReg(getEmptyStream);
    Reg#(Bool)       hasLastRemainReg <- mkReg(False);

    DataBitPtr headerBitLen = zeroExtend(headerLen) >> valueOf(BYTE_WIDTH_WIDTH);

    rule removeHeader;
        if (hasLastRemainReg) begin
            outFifo.enq(remainStreamReg);
            hasLastRemainReg <= False;
            remainStreamReg <= getEmptyStream;
        end
        else begin
            let stream = inFifo.first;
            inFifo.deq;
            let resStream = DataStream {
                data    : stream.data >> headerBitLen,
                byteEn  : stream.byteEn >> headerLen,
                isFirst : stream.isFirst,
                isLast  : stream.isLast
            };
            let removeStream = DataStream {
                data    : zeroExtend(Data'(stream.data[headerBitLen-1:0])),
                byteEn  : zeroExtend(ByteEn'(stream.byteEn[headerLen-1:0])),
                isFirst : False,
                isLast  : False
            };
            let newStream = DataStream {
                data    : remainStreamReg.data | stream.data << headerBitLen,
                byteEn  : remainStreamReg.byteEn | stream.byteEn << headerLen,
                isFirst : stream.isFirst,
                isLast  : stream.isLast
            };
            if (stream.isLast && stream.isFirst) begin 
                outFifo.enq(resStream);
            end
            else if (stream.isFirst) begin
                remainStreamReg <= resStream;
            end
            else begin
                outFifo.enq(newStream);
                if (stream.isLast) begin    
                    if(isByteEnZero(resStream.byteEn)) begin
                        remainStreamReg <= getEmptyStream;
                        hasLastRemainReg <= False;
                    end
                    else begin
                        remainStreamReg <= resStream;
                        hasLastRemainReg <= True;
                    end
                end
            end
        end
    endrule

    interface streamFifoIn  = convertFifoToFifoIn(inFifo);
    interface streamFifoOut = convertFifoToFifoOut(outFifo);
endmodule

// Only support one not full dataStream between streams
module mkStreamReshape(StreamPipe);
    FIFOF#(DataStream) inFifo  <- mkFIFOF;
    FIFOF#(DataStream) outFifo <- mkFIFOF;

    //During Stream Varibles
    Reg#(DataBytePtr) rmBytePtrReg     <- mkReg(0);
    Reg#(DataBitPtr)  rmBitPtrReg      <- mkReg(0);
    Reg#(DataBytePtr) rsBytePtrReg     <- mkReg(0);
    Reg#(DataBitPtr)  rsBitPtrReg      <- mkReg(0);
    Reg#(Bool)        isDetectedReg    <- mkReg(False);
    Reg#(DataStream)  remainStreamReg  <- mkReg(getEmptyStream);
    Reg#(Bool)        hasLastRemainReg <- mkReg(False);

    rule shape;
        if (hasLastRemainReg) begin
            outFifo.enq(remainStreamReg);
            isDetectedReg <= False;
            hasLastRemainReg <= False;
        end
        else begin
            let stream = inFifo.first;
            inFifo.deq;
            Bool isDetect = !stream.isLast && !isByteEnFull(stream.byteEn) && (!isDetectedReg);
            if (isDetect) begin
                let bytePtr = convertByteEn2BytePtr(stream.byteEn);
                DataBitPtr bitPtr = zeroExtend(bytePtr) >> valueOf(BYTE_WIDTH_WIDTH);
                rmBytePtrReg <= bytePtr;
                rmBitPtrReg  <= bitPtr;
                rsBytePtrReg <= getMaxBytePtr - bytePtr;
                rsBitPtrReg  <= getMaxBitPtr - bitPtr;
                remainStreamReg <= stream;
                isDetectedReg <= True;
            end
            else begin
                if (isDetectedReg) begin
                    let remainStream = DataStream {
                        data    : stream.data >> rsBitPtrReg,
                        byteEn  : stream.byteEn >> rsBytePtrReg,
                        isFirst : stream.isFirst,
                        isLast  : True
                    };
                    remainStreamReg <= remainStream;
                    let isLast = isByteEnZero(remainStream.byteEn);
                    let outStream = DataStream {
                        data    : (stream.data << rmBitPtrReg) | remainStreamReg.data,
                        byteEn  : (stream.byteEn << rmBytePtrReg) | remainStreamReg.byteEn,
                        isFirst : remainStreamReg.isFirst,
                        isLast  : isLast
                    };
                    outFifo.enq(outStream);
                    hasLastRemainReg <= !isLast;
                    isDetectedReg <= isLast ? False : isDetectedReg;
                end
                else begin
                    outFifo.enq(stream);
                end
            end
        end
    endrule

    interface streamFifoIn  = convertFifoToFifoIn(inFifo);
    interface streamFifoOut = convertFifoToFifoOut(outFifo);
endmodule
