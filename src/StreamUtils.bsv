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
    interface FifoIn#(DataStream)   inputStreamFirstFifoIn;
    interface FifoIn#(DataStream)   inputStreamSecondFifoIn;
    interface FifoOut#(DataStream)  outputStreamFifoOut;
    interface FifoOut#(DataBytePtr) outputBytePtrFifoOut;
endinterface

interface StreamSplit;
    interface FifoIn#(DataStream)  inputStreamFifoIn;
    interface FifoIn#(StreamSize)  splitLocationFifoIn;
    interface FifoOut#(DataStream) outputStreamFifoOut;
endinterface

function Bool isByteEnZero(ByteEn byteEn);
    return !unpack(byteEn[0]);
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

(* synthesize *)
module mkStreamConcat (StreamConcat ifc);

    FIFOF#(DataStream) inputFifoA <- mkFIFOF;
    FIFOF#(DataStream) inputFifoB <- mkFIFOF;
    FIFOF#(DataStream) outputFifo <- mkFIFOF;
    FIFOF#(DataBytePtr)    bytePtrFifo <- mkFIFOF;

    FIFOF#(StreamWithPtr) prepareFifoA <- mkFIFOF;
    FIFOF#(StreamWithPtr) prepareFifoB <- mkFIFOF;


    Reg#(Bool) hasRemainReg     <- mkReg(False);
    Reg#(Bool) hasLastRemainReg <- mkReg(False);
    Reg#(Bool) isStreamAEndReg  <- mkReg(False);

    Reg#(StreamWithPtr) remainStreamWpReg <- mkRegU;
    
    // Pipeline stage 1: get the bytePtr of each stream
    rule prepareStream;
        if (inputFifoA.notEmpty) begin
            let streamA = inputFifoA.first;
            inputFifoA.deq;
            let bytePtr = convertByteEn2BytePtr(streamA.byteEn);
            prepareFifoA.enq(StreamWithPtr {
                stream: streamA,
                bytePtr: bytePtr
            });
        end
        if (inputFifoB.notEmpty) begin
            let streamB = inputFifoB.first;
            inputFifoB.deq;
            let bytePtr = convertByteEn2BytePtr(streamB.byteEn);
            prepareFifoB.enq(StreamWithPtr {
                stream: streamB,
                bytePtr: bytePtr
            });
        end
    endrule

    // Pipeline stage 2: concat the stream frame
    rule concatStream;
        // Only the remain data
        if (hasRemainReg && hasLastRemainReg) begin
            outputFifo.enq(remainStreamWpReg.stream);
            bytePtrFifo.enq(remainStreamWpReg.bytePtr);
            hasRemainReg    <= False;
            isStreamAEndReg <= False;
        end
        // StreamB or streamB + the remain data
        else if (prepareFifoB.notEmpty && isStreamAEndReg) begin
            let streamBWp = prepareFifoB.first;
            prepareFifoB.deq;
            streamBWp.stream.isFirst = False;
            if (hasRemainReg) begin
                let {concatStreamWp, remainStreamWp} = getConcatStream(remainStreamWpReg, streamBWp);
                hasRemainReg      <= !isByteEnZero(remainStreamWp.stream.byteEn);
                hasLastRemainReg  <= streamBWp.stream.isLast;    
                remainStreamWpReg <= remainStreamWp;
                outputFifo.enq(concatStreamWp.stream);
                bytePtrFifo.enq(concatStreamWp.bytePtr);
            end
            else begin
                outputFifo.enq(streamBWp.stream);
                bytePtrFifo.enq(streamBWp.bytePtr);
            end
            // reset isStreamAEnd to False when the whole concat end
            isStreamAEndReg <= streamBWp.stream.isLast ? False : isStreamAEndReg;   
        end
        // StreamA or StreamA + first StreamB
        else if (prepareFifoA.notEmpty) begin
            let streamAWp = prepareFifoA.first;
            // Only StreamA frame
            if (!streamAWp.stream.isLast) begin
                outputFifo.enq(streamAWp.stream);
                bytePtrFifo.enq(streamAWp.bytePtr);
                prepareFifoA.deq;
                isStreamAEndReg <= False;
            end 
            // the last StreamA + the first StreamB
            else if(streamAWp.stream.isLast && prepareFifoB.notEmpty) begin
                let streamBWp = prepareFifoB.first;
                let {concatStreamWp, remainStreamWp} = getConcatStream(streamAWp, streamBWp);
                hasRemainReg       <= !isByteEnZero(remainStreamWp.stream.byteEn);
                hasLastRemainReg   <= streamBWp.stream.isLast;
                remainStreamWpReg  <= remainStreamWp;
                // If streamB.isLast, reset isStreamAEnd; otherwise assert isStreamAEnd
                isStreamAEndReg     <= streamBWp.stream.isLast ? False : True;
                outputFifo.enq(concatStreamWp.stream);
                bytePtrFifo.enq(concatStreamWp.bytePtr);
                prepareFifoA.deq;
                prepareFifoB.deq;
            end
            // Do nothing
            else begin
                // - !prepareB.notEmpty  ==> waiting StreamB for concatation
            end
        end
        // Do nothing
        else begin
            // - prepareB.notEmpty && !isStreamAEnd       ==> waiting streamAEnd asserts
            // - !prepareB.notEmpty && !prepareA.notEmpty ==> waiting new data 
        end
    endrule

    interface inputStreamFirstFifoIn  = convertFifoToFifoIn(inputFifoA);
    interface inputStreamSecondFifoIn = convertFifoToFifoIn(inputFifoB);
    interface outputStreamFifoOut     = convertFifoToFifoOut(outputFifo);
    interface outputBytePtrFifoOut    = convertFifoToFifoOut(bytePtrFifo);

endmodule

typedef 3 STREAM_SPLIT_LATENCY;

(* synthesize *)
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
            offsetBytePtr = truncate(pack(splitLocation - streamByteCntReg));
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