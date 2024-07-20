import Vector::*;
import FIFOF::*;
import GetPut::*;
import SemiFifo::*;

import PrimUtils::*;
import DmaTypes::*;

typedef 32 STREAM_SIZE_WIDTH;
typedef UInt#(STREAM_SIZE_WIDTH) StreamSize;
typedef Bit#(TAdd#(1, TLog#(STREAM_SIZE_WIDTH))) StreamSizeBitPtr;

typedef struct {
    DataStream stream;
    DataBytePtr bytePtr;
} StreamWithPtr deriving(Bits, Bounded, Eq, FShow);

interface StreamConcat;
    interface FifoIn#(DataStream)  inputStreamFirstFifoIn;
    interface FifoIn#(DataStream)  inputStreamSecondFifoIn;
    interface FifoOut#(DataStream) outputStreamFifoOut;
endinterface

interface StreamSplit;
    interface FifoIn#(DataStream)  inputStreamFifoIn;
    interface FifoIn#(StreamSize)  splitLocationFifoIn;
    interface FifoOut#(DataStream) outputStreamFifoOut;
endinterface

function DataBytePtr convertByteEn2BytePtr (ByteEn byteEn);
    DataBytePtr ptr = 0;
    case(byteEn)
        'h0000000000000001: ptr = 1;
        'h0000000000000003: ptr = 2;
        'h0000000000000007: ptr = 3;
        'h000000000000000F: ptr = 4;
        'h000000000000001F: ptr = 5;
        'h000000000000003F: ptr = 6;
        'h000000000000007F: ptr = 7;
        'h00000000000000FF: ptr = 8;
        'h00000000000001FF: ptr = 9;
        'h00000000000003FF: ptr = 10;
        'h00000000000007FF: ptr = 11;
        'h0000000000000FFF: ptr = 12;
        'h0000000000001FFF: ptr = 13;
        'h0000000000003FFF: ptr = 14;
        'h0000000000007FFF: ptr = 15;
        'h000000000000FFFF: ptr = 16;
        'h000000000001FFFF: ptr = 17;
        'h000000000003FFFF: ptr = 18;
        'h000000000007FFFF: ptr = 19;
        'h00000000000FFFFF: ptr = 20;
        'h00000000001FFFFF: ptr = 21;
        'h00000000003FFFFF: ptr = 22;
        'h00000000007FFFFF: ptr = 23;
        'h0000000000FFFFFF: ptr = 24;
        'h0000000001FFFFFF: ptr = 25;
        'h0000000003FFFFFF: ptr = 26;
        'h0000000007FFFFFF: ptr = 27;
        'h000000000FFFFFFF: ptr = 28;
        'h000000001FFFFFFF: ptr = 29;
        'h000000003FFFFFFF: ptr = 30;
        'h000000007FFFFFFF: ptr = 31;
        'h00000000FFFFFFFF: ptr = 32;
        'h00000001FFFFFFFF: ptr = 33;
        'h00000003FFFFFFFF: ptr = 34;
        'h00000007FFFFFFFF: ptr = 35;
        'h0000000FFFFFFFFF: ptr = 36;
        'h0000001FFFFFFFFF: ptr = 37;
        'h0000003FFFFFFFFF: ptr = 38;
        'h0000007FFFFFFFFF: ptr = 39;
        'h000000FFFFFFFFFF: ptr = 40;
        'h000001FFFFFFFFFF: ptr = 41;
        'h000003FFFFFFFFFF: ptr = 42;
        'h000007FFFFFFFFFF: ptr = 43;
        'h00000FFFFFFFFFFF: ptr = 44;
        'h00001FFFFFFFFFFF: ptr = 45;
        'h00003FFFFFFFFFFF: ptr = 46;
        'h00007FFFFFFFFFFF: ptr = 47;
        'h0000FFFFFFFFFFFF: ptr = 48;
        'h0001FFFFFFFFFFFF: ptr = 49;
        'h0003FFFFFFFFFFFF: ptr = 50;
        'h0007FFFFFFFFFFFF: ptr = 51;
        'h000FFFFFFFFFFFFF: ptr = 52;
        'h001FFFFFFFFFFFFF: ptr = 53;
        'h003FFFFFFFFFFFFF: ptr = 54;
        'h007FFFFFFFFFFFFF: ptr = 55;
        'h00FFFFFFFFFFFFFF: ptr = 56;
        'h01FFFFFFFFFFFFFF: ptr = 57;
        'h03FFFFFFFFFFFFFF: ptr = 58;
        'h07FFFFFFFFFFFFFF: ptr = 59;
        'h0FFFFFFFFFFFFFFF: ptr = 60;
        'h1FFFFFFFFFFFFFFF: ptr = 61;
        'h3FFFFFFFFFFFFFFF: ptr = 62;
        'h7FFFFFFFFFFFFFFF: ptr = 63;
        'hFFFFFFFFFFFFFFFF: ptr = 64;
        default           : ptr = 0;
    endcase
    return ptr;
endfunction

function Bool isByteEnZero(ByteEn byteEn) begin
    return !unpack(remainStream.byteEn[0]);
end

function DataStream getEmptyStream ();
    return DataStream{
        data: 0,
        byteEn: 0,
        isFirst: False,
        isLast: True
    };
endfunction

function DataBitPtr getMaxBitPtr ();
    return fromInteger(valueOf(DATA_WIDTH));
endfunction

function DataBytePtr getMaxBytePtr ();
    return fromInteger(valueOf(BYTE_EN_WIDTH));
endfunction

// Concat two DataStream frames into one. StreamA.isLast must be True, otherwise the function will return a empty frame to end the stream.
function Tuple3#(DataStream, DataStream, DataBytePtr) getConcatStream (DataStream streamA, DataStream streamB, DataBytePtr bytePtrA, DataBytePtr bytePtrB);
    Bool isCallLegally = (streamA.isLast && bytePtrA <= getMaxBytePtr && bytePtrA > 0);
    DataBitPtr bitPtrA = zeroExtend(bytePtrA) << fromInteger(valueOf(BYTE_WIDTH_WIDTH));

    // Fill the low PtrA bytes by streamA data
    Data   concatDataA   = streamA.data;
    ByteEn concatByteEnA = streamA.byteEn;

    // Fill the high bytes by streamB data
    Data   concatDataB   = streamB.data << bitPtrA;
    ByteEn concatByteEnB = streamB.byteEn << bytePtrA;
    Data   concatData    = concatDataA | concatDataB;
    ByteEn concatByteEn  = concatByteEnA | concatByteEnB;

    // Get the remain bytes of streamB data
    DataBitPtr  resBitPtr    = getMaxBitPtr - bitPtrA;
    DataBytePtr resBytePtr   = getMaxBytePtr - bytePtrA;
    Data        remainData   = streamB.data >> resBitPtr;
    ByteEn      remainByteEn = streamB.byteEn >> resBytePtr;

    // Get if the concat frame is the last
    Bool        isConcatStreamLast = streamB.isLast;
    DataBytePtr remainBytePtr      = 0;
    if (resBytePtr < bytePtrB ) begin    
        isConcatStreamLast = False;
        remainBytePtr      = bytePtrB - resBytePtr;
    end
     DataStream concatStream = getEmptyStream;
     DataStream remainStream = getEmptyStream;

    // package the return concatStream and remainStream
    if(isCallLegally) begin
        concatStream = DataStream {
            data   : concatData,
            byteEn : concatByteEn,
            isFirst: streamA.isFirst,
            isLast : isConcatStreamLast
        };
        remainStream = DataStream {
            data   : remainData,
            byteEn : remainByteEn,
            isFirst: False,
            isLast : True
        };
    end
    return tuple3(concatStream, remainStream, remainBytePtr);
endfunction

(* synthesize *)
module mkStreamConcat (StreamConcat ifc);

    FIFOF#(DataStream) inputFifoA <- mkFIFOF;
    FIFOF#(DataStream) inputFifoB <- mkFIFOF;
    FIFOF#(DataStream) outputFifo <- mkFIFOF;

    FIFOF#(StreamWithPtr) prepareFifoA <- mkFIFOF;
    FIFOF#(StreamWithPtr) prepareFifoB <- mkFIFOF;

    Reg#(DataBytePtr) bytePtrRegA <- mkReg(0);
    Reg#(DataBytePtr) bytePtrRegB <- mkReg(0);
    Reg#(DataBytePtr) remainBytePtrReg <- mkReg(0);

    Reg#(Bool) hasRemainReg <- mkReg(False);
    Reg#(Bool) hasLastRemainReg <- mkReg(False);
    Reg#(Bool) isStreamAEnd <- mkReg(False);

    Reg#(DataStream) remainStreamReg <- mkRegU;
    

    rule prepareStreamA;
        let streamA = inputFifoA.first;
        inputFifoA.deq;
        DataBytePtr bytePtr = convertByteEn2BytePtr(streamA.byteEn);
        prepareFifoA.enq(StreamWithPtr {
            stream: streamA,
            bytePtr: bytePtr
        });
    endrule

    rule prepareStreamB;
        let streamB = inputFifoB.first;
        inputFifoB.deq;
        DataBytePtr bytePtr = convertByteEn2BytePtr(streamB.byteEn);
        prepareFifoB.enq(StreamWithPtr {
            stream: streamB,
            bytePtr: bytePtr
        });
    endrule

    rule concatStream;
        // Only the remain data
        if (hasRemainReg && hasLastRemainReg) begin
            outputFifo.enq(remainStreamReg);
            hasRemainReg <= False;
            isStreamAEnd <= False;
        end
        // StreamB or streamB + the remain data
        else if (prepareFifoB.notEmpty && isStreamAEnd) begin
            let streamB = prepareFifoB.first.stream;
            let bytePtrB = prepareFifoB.first.bytePtr;
            prepareFifoB.deq;
            streamB.isFirst = False;
            if (hasRemainReg) begin
                let {concatStream, remainStream, remainBytePtr} = getConcatStream(remainStreamReg, streamB, remainBytePtrReg, bytePtrB);
                hasRemainReg     <= !isByteEnZero(remainStream.byteEn);
                hasLastRemainReg <= streamB.isLast;
                remainStreamReg  <= remainStream;
                remainBytePtrReg <= remainBytePtr;
                outputFifo.enq(concatStream);
            end
            else begin
                outputFifo.enq(streamB);
            end
            isStreamAEnd <= !streamB.isLast;
        end
        // StreamA or StreamA + first StreamB
        else if (prepareFifoA.notEmpty) begin
            let streamA = prepareFifoA.first.stream;
            let bytePtrA = prepareFifoA.first.bytePtr;
            // Only StreamA frame
            if (!streamA.isLast) begin
                outputFifo.enq(streamA);
                prepareFifoA.deq;
                isStreamAEnd <= False;
            end 
            // the last StreamA + the first StreamB
            else if (streamA.isLast && prepareFifoB.notEmpty) begin
                let streamB = prepareFifoB.first.stream;
                let bytePtrB = prepareFifoB.first.bytePtr;
                let {concatStream, remainStream, remainBytePtr} = getConcatStream(streamA, streamB, bytePtrA, bytePtrB);
                hasRemainReg     <= !isByteEnZero(remainStream.byteEn);
                hasLastRemainReg <= streamB.isLast;
                remainStreamReg  <= remainStream;
                remainBytePtrReg <= remainBytePtr;
                isStreamAEnd     <= !streamB.isLast;
                outputFifo.enq(concatStream);
                prepareFifoA.deq;
                prepareFifoB.deq;
            end
        end
    endrule

    interface inputStreamFirstFifoIn  = convertFifoToFifoIn(inputFifoA);
    interface inputStreamSecondFifoIn = convertFifoToFifoIn(inputFifoB);
    interface outputStreamFifoOut     = convertFifoToFifoOut(outputFifo);

endmodule

(* synthesize *)
module mkStreamSplit(StreamSplit ifc);

    Reg#(StreamSize) streamByteCntReg <- mkReg(0);

    FIFOF#(StreamSize)    splitLocationFifo <- mkFIFOF;
    FIFOF#(DataStream)    inputFifo         <- mkFIFOF;
    FIFOF#(DataStream)    outputFifo        <- mkFIFOF;
    FIFOF#(StreamWithPtr) prepareFifo       <- mkFIFOF;
    FIFOF#(StreamWithPtr) assertFifo        <- mkFIFOF;
    FIFOF#(Tuple2#(DataBytePtr,DataBytePtr)) splitPtrFifo <- mkFIFOF;

    Reg#(DataStream)  remainStreamReg  <- mkRegU;
    Reg#(DataBytePtr) remainBytePtrReg <- mkReg(0);

    Reg#(Bool) hasRemainReg     <- mkReg(False);
    Reg#(Bool) hasLastRemainReg <- mkReg(False);
    Reg#(Bool) isSplitted       <- mkReg(False);
    
    rule prepareStream;
        let stream = inputFifo.first;
        inputFifo.deq;
        StreamWithPtr streamWithPtr = StreamWithPtr {
            stream: stream,
            bytePtr: convertByteEn2BytePtr(stream.byteEn) 
        };
        prepareFifo.enq(streamWithPtr);
    endrule

    rule assertSplitStream;
        let stream = prepareFifo.first.stream;
        let bytePtr = prepareFifo.first.bytePtr;        
        let splitLocation = splitLocationFifo.first;
        DataBytePtr truncateBytePtr = 0;
        if (!isSplitted && unpack(zeroExtend(bytePtr)) + streamByteCntReg >= splitLocation) begin
            truncateBytePtr = truncate(pack(splitLocation - streamByteCntReg));
        end
        DataBytePtr resBytePtr = getMaxBytePtr - truncateBytePtr;
        splitPtrFifo.enq(tuple2(truncateBytePtr, resBytePtr));
        if (truncateBytePtr > 0 && !stream.isLast) begin
            isSplitted <= True;
        end 
        else if (stream.isLast) begin
            isSplitted <= False;
        end
        streamByteCntReg <= stream.isLast ? 0 : streamByteCntReg + unpack(zeroExtend(bytePtr));
        assertFifo.enq(prepareFifo.first);
        prepareFifo.deq;
        if (stream.isLast) begin
            splitLocationFifo.deq;
        end
    endrule


    rule execSplitStream;
        // Only output remainStreamReg
        if (hasRemainReg && hasLastRemainReg) begin
            outputFifo.enq(remainStreamReg);
            hasRemainReg <= False;
            hasLastRemainReg <= False;
        end
        else if (assertFifo.notEmpty && splitPtrFifo.notEmpty) begin
            let stream = assertFifo.first.stream;
            let frameBytePtr = assertFifo.first.bytePtr;
            let {truncateBytePtr, resBytePtr} = splitPtrFifo.first;
            assertFifo.deq;
            splitPtrFifo.deq;
            // no operatation
            if (!hasRemainReg && truncateBytePtr == 0) begin
                outputFifo.enq(stream);
            end
            // split the frame in this cycle to a last frame and a remain frame
            else if (!hasRemainReg && truncateBytePtr > 0) begin
                DataBitPtr truncateBitPtr = zeroExtend(truncateBytePtr) << valueOf(BYTE_WIDTH_WIDTH);
                DataBitPtr resBitPtr = zeroExtend(resBytePtr) << valueOf(BYTE_WIDTH_WIDTH);
                outputFifo.enq(DataStream {
                    data: (stream.data << resBitPtr) >> resBitPtr,
                    byteEn: (stream.byteEn << resBytePtr) >> resBytePtr,
                    isFirst: stream.isFirst,
                    isLast: True
                });
                DataStream remainStream = DataStream {
                    data: stream.data >> truncateBitPtr,
                    byteEn: stream.byteEn >> truncateBytePtr,
                    isFirst: True,
                    isLast: True
                };
                hasRemainReg     <= !isByteEnZero(remainStream.byteEn);
                hasLastRemainReg <= stream.isLast;
                remainBytePtrReg <= frameBytePtr - truncateBytePtr;
                remainStreamReg  <= remainStream;
            end
            // concat the new frame with the remainReg
            else if (hasRemainReg) begin
                let {concatStream, remainStream, remainBytePtr} = getConcatStream(remainStreamReg, stream, remainBytePtrReg, frameBytePtr);
                outputFifo.enq(concatStream);
                hasRemainReg     <= !isByteEnZero(remainStream.byteEn);
                hasLastRemainReg <= stream.isLast;
                remainStreamReg  <= remainStream;
                remainBytePtrReg <= remainBytePtr;
            end
        end
    endrule

    interface inputStreamFifoIn   = convertFifoToFifoIn(inputFifo);
    interface splitLocationFifoIn = convertFifoToFifoIn(splitLocationFifo);
    interface outputStreamFifoOut = convertFifoToFifoOut(outputFifo);

endmodule