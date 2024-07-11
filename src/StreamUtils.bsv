import Vector::*;
import FIFOF::*;
import GetPut::*;
import SemiFifo::*;

typedef 8 BYTE_WIDTH;
typedef TLog#(BYTE_WIDTH) BYTE_WIDTH_WIDTH;
typedef TMul#(4, BYTE_WIDTH) DWORD_WIDTH;

typedef 2 CONCAT_STREAM_NUM;

typedef 512 DATA_WIDTH;
typedef TDiv#(DATA_WIDTH, BYTE_WIDTH) BYTE_EN_WIDTH;
typedef 'hFFFFFFFFFFFFFFFF MAX_BYTE_EN;

typedef Bit#(DATA_WIDTH) Data;
typedef Bit#(BYTE_EN_WIDTH) ByteEn;
typedef Bit#(TAdd#(1, TLog#(DATA_WIDTH))) BitPtr;
typedef Bit#(TAdd#(1, TLog#(BYTE_EN_WIDTH))) BytePtr;

typedef UInt#(32) StreamSize;

typedef struct {
    Data data;
    ByteEn byteEn;
    Bool isFirst;
    Bool isLast;
} DataStream deriving(Bits, Bounded, Eq, FShow);

typedef struct {
    DataStream stream;
    BytePtr bytePtr;
} StreamWithPtr deriving(Bits, Bounded, Eq, FShow);

interface StreamConcat;
    interface FifoIn#(DataStream)  inputStreamFirst;
    interface FifoIn#(DataStream)  inputStreamSecond;
    interface FifoOut#(DataStream) outputStream;
endinterface

interface StreamSplit;
    interface FifoIn#(DataStream)  inputStream;
    interface Put#(StreamSize) setSplitPtr;
    interface FifoOut#(DataStream) outputStream;
endinterface

function BytePtr convertByteEn2BytePtr (ByteEn byteEn);
    ByteEn byteEnTemp = byteEn;
    BytePtr ptr = 0;
    while (byteEnTemp > 0) begin
        byteEnTemp = byteEnTemp >> 1;
        ptr = ptr + 1;
    end
    return ptr;
endfunction

function Action showDataStream (DataStream stream);
    return action
        $display("   Data = %h", stream.data);
        $display("   byteEn = %b", stream.byteEn);
        $display("   isFirst = %b, isLast = %b", stream.isFirst, stream.isLast);
    endaction;
endfunction

function Action checkDataStream (DataStream stream, String name);
    if (stream.byteEn == 0 || stream.data == 0) begin 
        return action
            $display("Error: wrong dataStream ", name);
            showDataStream(stream);
            $finish();
        endaction;
    end 
    else begin
        return action
        endaction;
    end
endfunction

(* synthesize *)
module mkStreamConcat (StreamConcat ifc);

    FIFOF#(DataStream) inputFifoA <- mkFIFOF;
    FIFOF#(DataStream) inputFifoB <- mkFIFOF;
    FIFOF#(DataStream) outputFifo <- mkFIFOF;

    FIFOF#(StreamWithPtr) prepareFifoA <- mkFIFOF;
    FIFOF#(StreamWithPtr) prepareFifoB <- mkFIFOF;

    Reg#(BytePtr) bytePtrRegA <- mkReg(0);
    Reg#(BytePtr) bytePtrRegB <- mkReg(0);
    Reg#(BytePtr) remainBytePtrReg <- mkReg(0);
    Reg#(Bool) hasRemainReg <- mkReg(False);
    Reg#(DataStream) remainStreamReg <- mkRegU;

    DataStream emptyStream = DataStream{
        data: 0,
        byteEn: 0,
        isFirst: True,
        isLast: True
    };

    BytePtr maxBytePtr = fromInteger(valueOf(BYTE_EN_WIDTH));
    BitPtr maxBitPtr = fromInteger(valueOf(DATA_WIDTH));

    function Tuple3#(DataStream, DataStream, BytePtr) getConcatStream (DataStream streamA, DataStream streamB, BytePtr bytePtrA, BytePtr bytePtrB);
        Bool isCallLegally = (streamA.isLast && bytePtrA <= maxBytePtr && bytePtrA > 0);
        BitPtr bitPtrA = zeroExtend(bytePtrA) << fromInteger(valueOf(BYTE_WIDTH_WIDTH));

        // Fill the low PtrA bytes by streamA data
        Data concatDataA = streamA.data;
        ByteEn concatByteEnA = streamA.byteEn;

        // Fill the high bytes by streamB data
        Data concatDataB = streamB.data << bitPtrA;
        ByteEn concatByteEnB = streamB.byteEn << bytePtrA;
        Data concatData = concatDataA | concatDataB;
        ByteEn concatByteEn = concatByteEnA | concatByteEnB;

        // Get the remain bytes of streamB data
        BitPtr resBitPtr = maxBitPtr - bitPtrA;
        BytePtr resBytePtr = maxBytePtr - bytePtrA;
        Data remainData = streamB.data >> resBitPtr;
        ByteEn remainByteEn = streamB.byteEn >> resBytePtr;

        // Get if the concat frame is the last
        Bool isConcatStreamLast = streamB.isLast;
        BytePtr remainBytePtr = 0;
        if (resBytePtr < bytePtrB ) begin    
            isConcatStreamLast = False;
            remainBytePtr = bytePtrB - resBytePtr;
        end
         DataStream concatStream = emptyStream;
         DataStream remainStream = emptyStream;

        // package the return concatStream and remainStream
        if(isCallLegally) begin
            concatStream = DataStream{
                data: concatData,
                byteEn: concatByteEn,
                isFirst: streamA.isFirst,
                isLast: isConcatStreamLast
            };
            remainStream = DataStream{
                data: remainData,
                byteEn: remainByteEn,
                isFirst: False,
                isLast: True
            };
        end
        return tuple3(concatStream, remainStream, remainBytePtr);
    endfunction

    rule prepareStreamA;
        let streamA = inputFifoA.first;
        inputFifoA.deq;
        BytePtr bytePtr = convertByteEn2BytePtr(streamA.byteEn);
        prepareFifoA.enq(StreamWithPtr {
            stream: streamA,
            bytePtr: bytePtr
        });
    endrule

    rule prepareStreamB;
        let streamB = inputFifoB.first;
        inputFifoB.deq;
        BytePtr bytePtr = convertByteEn2BytePtr(streamB.byteEn);
        prepareFifoB.enq(StreamWithPtr {
            stream: streamB,
            bytePtr: bytePtr
        });
    endrule

    rule concatStream;
        // StreamA or StreamA + first StreamB
        if (prepareFifoA.notEmpty && prepareFifoB.notEmpty && !hasRemainReg) begin
            let streamA = prepareFifoA.first.stream;
            let streamB = prepareFifoB.first.stream;
            let bytePtrA = prepareFifoA.first.bytePtr;
            let bytePtrB = prepareFifoB.first.bytePtr;
            // Only StreamA frame
            if (!streamA.isLast && streamB.isFirst) begin
                outputFifo.enq(streamA);
                prepareFifoA.deq;
            end 
            // the last StreamA + the first StreamB
            else if (streamA.isLast && streamB.isFirst) begin
                match{.concatStream, .remainStream, .remainBytePtr} = getConcatStream(streamA, streamB, bytePtrA, bytePtrB);
                Bool hasRemain = unpack(remainStream.byteEn[0]);
                hasRemainReg <= hasRemain;
                remainStreamReg <= remainStream;
                remainBytePtrReg <= remainBytePtr;
                outputFifo.enq(concatStream);
                prepareFifoA.deq;
                prepareFifoB.deq;
            end
        end

        // streamB + the remain data
        else if (prepareFifoB.notEmpty && hasRemainReg) begin
            let streamB = prepareFifoB.first.stream;
            let bytePtrB = prepareFifoB.first.bytePtr;
            if (!streamB.isFirst) begin
                match{.concatStream, .remainStream, .remainBytePtr} = getConcatStream(remainStreamReg, streamB, remainBytePtrReg, bytePtrB);
                Bool hasRemain = unpack(remainStream.byteEn[0]);
                hasRemainReg <= hasRemain;
                remainStreamReg <= remainStream;
                remainBytePtrReg <= remainBytePtr;
                outputFifo.enq(concatStream);
                prepareFifoB.deq;
            end
            else begin
                outputFifo.enq(remainStreamReg);
                hasRemainReg <= False;
            end
        end

        // Only the remain data
        else if (hasRemainReg) begin
            outputFifo.enq(remainStreamReg);
            hasRemainReg <= False;
        end
    endrule

    interface inputStreamFirst = convertFifoToFifoIn(inputFifoA);
    interface inputStreamSecond = convertFifoToFifoIn(inputFifoB);
    interface outputStream = convertFifoToFifoOut(outputFifo);

endmodule

(* synthesize *)
module mkStreamSplit(StreamSplit ifc);

    Reg#(Maybe#(StreamSize)) splitLocationMaybeReg <- mkReg(Invalid);

    FIFOF#(DataStream) inputFifo <- mkFIFOF;
    FIFOF#(DataStream) outputFifo <- mkFIFOF;

    interface Put setSplitPtr;
        method Action put(StreamSize splitPtr);

        endmethod
    endinterface

    interface inputStream = convertFifoToFifoIn(inputFifo);
    interface outputStream = convertFifoToFifoOut(outputFifo);

endmodule