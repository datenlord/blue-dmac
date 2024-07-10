import Vector::*;
import FIFOF::*;
import SemiFifo::*;

typedef 8 BYTE_WIDTH;
typedef TLog#(BYTE_WIDTH) BYTE_WIDTH_WIDTH;
typedef TMul#(4, BYTE_WIDTH) DWORD_WIDTH;

typedef 2 CONCAT_STREAM_NUM;

typedef 512 DATA_WIDTH;
typedef TDiv#(DATA_WIDTH, BYTE_WIDTH) BYTE_EN_WIDTH;

typedef Bit#(DATA_WIDTH) Data;
typedef Bit#(BYTE_EN_WIDTH) ByteEn;
typedef Bit#(TAdd#(1, TLog#(DATA_WIDTH))) BitPtr;
typedef Bit#(TAdd#(1, TLog#(BYTE_EN_WIDTH))) BytePtr;

typedef struct {
    Data data;
    ByteEn byteEn;
    Bool isFirst;
    Bool isLast;
} DataStream deriving(Bits, Bounded, Eq, FShow);

interface StreamConcat;
    interface FifoIn#(DataStream)  inputStreamFirst;
    interface FifoIn#(DataStream)  inputStreamSecond;
    interface FifoOut#(DataStream) outputStream;
endinterface

module mkStreamConcat (StreamConcat ifc);

    FIFOF#(DataStream) inputFifoA <- mkFIFOF;
    FIFOF#(DataStream) inputFifoB <- mkFIFOF;
    FIFOF#(DataStream) outputFifo <- mkFIFOF;

    FIFOF#(DataStream) prepareFifoA <- mkFIFOF;
    FIFOF#(DataStream) prepareFifoB <- mkFIFOF;

    Reg#(BytePtr) bytePtrRegA <- mkReg(0);
    Reg#(BytePtr) bytePtrRegB <- mkReg(0);
    Reg#(BytePtr) remainBytePtrReg <- mkReg(0);
    Reg#(Bool) hasRemainReg <- mkReg(False);
    Reg#(DataStream) remainStreamReg <- mkRegU;

    DataStream emptyStream = DataStream{
        data: 0,
        byteEn: 0,
        isFirst: False,
        isLast: False
    };

    BytePtr maxBytePtr = fromInteger(valueOf(BYTE_EN_WIDTH));
    BitPtr maxBitPtr = fromInteger(valueOf(DATA_WIDTH));

    function BytePtr getByteConcatPtr (ByteEn byteEn);
        ByteEn byteEnTemp = byteEn;
        BytePtr ptr = 0;
        while (byteEnTemp > 0) begin
            byteEnTemp = byteEnTemp >> 1;
            ptr = ptr + 1;
        end
        return ptr;
    endfunction

    function Tuple3#(DataStream, DataStream, BytePtr) getConcatStream (
        DataStream streamA, DataStream streamB, BytePtr bytePtrA, BytePtr bytePtrB
    );
        Bool isCallLegally = (streamA.isLast && bytePtrA < maxBytePtr && bytePtrA > 0);
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
                isFirst: streamA.isLast,
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

    rule prepareStream;
        let streamA = inputFifoA.first;
        let streamB = inputFifoB.first;
        inputFifoA.deq;
        inputFifoB.deq;
        prepareFifoA.enq(streamA);
        prepareFifoB.enq(streamB);
        bytePtrRegA <= streamA.isLast ? getByteConcatPtr(streamA.byteEn) : bytePtrRegA;
        bytePtrRegB <= streamB.isLast ? getByteConcatPtr(streamB.byteEn) : maxBytePtr;
    endrule

    rule concatStream;
        let streamA = prepareFifoA.first;
        let streamB = prepareFifoB.first;
        // Only StreamA
        if (!hasRemainReg && !streamA.isLast && streamB.isFirst) begin
            outputFifo.enq(streamA);
            prepareFifoA.deq;
        end 
        // the last StreamA + the first StreamB
        else if (!hasRemainReg && streamA.isLast && streamB.isFirst) begin
            $display(bytePtrRegA);
            match{.concatStream, .remainStream, .remainBytePtr} = getConcatStream(streamA, streamB, bytePtrRegA, bytePtrRegB);
            Bool hasRemain = unpack(remainStream.byteEn[0]);
            hasRemainReg <= hasRemain;
            remainStreamReg <= remainStream;
            remainBytePtrReg <= remainBytePtr;
            if (concatStream.byteEn[0] == 1) begin
                outputFifo.enq(concatStream);
            end
            prepareFifoA.deq;
            prepareFifoB.deq;
        end
        // streamB + the remain data
        else if (hasRemainReg && !streamB.isFirst) begin
            match{.concatStream, .remainStream, .remainBytePtr} = getConcatStream(remainStreamReg, streamB, remainBytePtrReg, bytePtrRegB);
            Bool hasRemain = unpack(remainStream.byteEn[0]);
            hasRemainReg <= hasRemain;
            remainStreamReg <= remainStream;
            remainBytePtrReg <= remainBytePtr;
            if (concatStream.byteEn[0] == 1) begin
                outputFifo.enq(concatStream);
            end
            prepareFifoB.deq;
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