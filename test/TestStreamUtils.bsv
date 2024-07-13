import FIFOF::*;
import SemiFifo::*;
import LFSR::*;
import StreamUtils::*;

typedef 'hAB PSEUDO_DATA;
typedef 8 PSEUDO_DATA_WIDTH;

typedef 10 TEST_IDEAL_FIFO_DEPTH;

typedef 'h12345678 SEED_1;
typedef 'hABCDEF01 SEED_2;

// TEST HYPER PARAMETERS CASE 1
// typedef 3 MAX_STREAM_SIZE_PTR;
// typedef 10 TEST_NUM;

// TEST HYPER PARAMETERS CASE 2
typedef 16 MAX_STREAM_SIZE_PTR;
typedef 10000 TEST_NUM;

typedef enum {
    WAITING, FirstChunk, SecondChunk
} StreamSplitOutStatus deriving(Bits, Eq);

interface RandomStreamSize;
    method ActionValue#(StreamSize) next();
endinterface

function Data getPseudoData();
    Data pseudoData = fromInteger(valueOf(PSEUDO_DATA));
    for (Integer idx = 0; idx < valueOf(TDiv#(DATA_WIDTH, PSEUDO_DATA_WIDTH)); idx = idx + 1) begin
        pseudoData = pseudoData | (pseudoData << idx*valueOf(PSEUDO_DATA_WIDTH));
    end
    return pseudoData;
endfunction

function DataStream generatePsuedoStream (StreamSize size, Bool isFirst, Bool isLast);
    let pseudoData = getPseudoData();
    let offsetPtr = (unpack(zeroExtend(getMaxBytePtr())) - size) << valueOf(BYTE_WIDTH_WIDTH);
    Data streamData = (pseudoData << offsetPtr) >> offsetPtr;
    return DataStream{
        data: streamData,
        byteEn: (1 << size) - 1,
        isFirst: isFirst,
        isLast: isLast
    };
endfunction

function StreamSize getMaxFrameSize (); 
    return fromInteger(valueOf(BYTE_EN_WIDTH));
endfunction

module mkRandomStreamSize(StreamSize seed, StreamSizeBitPtr maxSizeBitPtr, RandomStreamSize ifc);
    LFSR#(Bit#(STREAM_SIZE_WIDTH)) lfsr <- mkLFSR_32 ;
    FIFOF#(StreamSize) outputFifo <- mkFIFOF ;
    Reg#(Bool) isInitReg <- mkReg(False) ;

    rule run if (isInitReg);
        let value = lfsr.value >> (fromInteger(valueOf(STREAM_SIZE_WIDTH)) - maxSizeBitPtr);
        if (value > 0) begin
            outputFifo.enq(unpack(value));
        end
        lfsr.next;
    endrule

    rule init if (!isInitReg);
        isInitReg <= True;
        lfsr.seed(pack(seed));
    endrule

    method ActionValue#(StreamSize) next();
        outputFifo.deq;
        return outputFifo.first;
    endmethod
endmodule

(* doc = "testcase" *) 
module mkStreamConcatTb(Empty);

    StreamConcat dut <- mkStreamConcat;

    RandomStreamSize streamASizeRandomValue <- mkRandomStreamSize(fromInteger(valueOf(SEED_1)), fromInteger(valueOf(MAX_STREAM_SIZE_PTR)));
    RandomStreamSize streamBSizeRandomValue <- mkRandomStreamSize(fromInteger(valueOf(SEED_2)), fromInteger(valueOf(MAX_STREAM_SIZE_PTR)));

    Reg#(StreamSize) streamARemainSizeReg <- mkReg(0);
    Reg#(StreamSize) streamBRemainSizeReg <- mkReg(0);
    Reg#(StreamSize) concatSizeReg <- mkReg(0);

    FIFOF#(StreamSize) ideaConcatSizeFifo <- mkSizedFIFOF(valueOf(TEST_IDEAL_FIFO_DEPTH));
    
    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testCntReg <- mkReg(0);
    Reg#(UInt#(32)) testRoundReg <- mkReg(0);
    Reg#(UInt#(32)) testFinishCntReg <- mkReg(0);

    rule testInit if (!isInitReg);
        $display("INFO: ================start StreamConcatTb!==================");
        isInitReg <= True;
    endrule

    rule testInput if (isInitReg && testCntReg < fromInteger(valueOf(TEST_NUM)));
        if (testRoundReg == 0 && dut.inputStreamFirstFifoIn.notFull &&  dut.inputStreamSecondFifoIn.notFull) begin
            StreamSize sizeA <- streamASizeRandomValue.next;
            StreamSize sizeB <- streamBSizeRandomValue.next;
            ideaConcatSizeFifo.enq(sizeA + sizeB); 
            testRoundReg <= (sizeA + sizeB) / getMaxFrameSize();

            let isLastA = (sizeA <= getMaxFrameSize());
            let isLastB = (sizeB <= getMaxFrameSize());
            let firstSizeA = isLastA ? sizeA : getMaxFrameSize();
            let firstSizeB = isLastB ? sizeB : getMaxFrameSize();

            dut.inputStreamFirstFifoIn.enq(generatePsuedoStream(firstSizeA, True, isLastA));
            dut.inputStreamSecondFifoIn.enq(generatePsuedoStream(firstSizeB, True, isLastB));
            streamARemainSizeReg <= sizeA - firstSizeA;
            streamBRemainSizeReg <= sizeB - firstSizeB;
            testCntReg <= testCntReg + 1;
            // $display("INFO: Add Input of %d Epoch", testCntReg + 1);
            // $display("INFO: streamASize = %d, streamBSize = %d, ideaSize = %d", sizeA, sizeB, sizeA+sizeB);
        end

        else if (testRoundReg > 0) begin
            if (streamARemainSizeReg > 0 && dut.inputStreamFirstFifoIn.notFull) begin
                Bool isLast =  streamARemainSizeReg <= getMaxFrameSize();
                StreamSize size = isLast ? streamARemainSizeReg : getMaxFrameSize();
                dut.inputStreamFirstFifoIn.enq(generatePsuedoStream(size, False, isLast));
                streamARemainSizeReg <= streamARemainSizeReg - size;
            end
            if (streamBRemainSizeReg > 0 && dut.inputStreamSecondFifoIn.notFull) begin
                Bool isLast =  streamBRemainSizeReg <= getMaxFrameSize();
                StreamSize size = isLast ? streamBRemainSizeReg : getMaxFrameSize();
                dut.inputStreamSecondFifoIn.enq(generatePsuedoStream(size, False, isLast));
                streamBRemainSizeReg <= streamBRemainSizeReg - size;
            end
            testRoundReg <= testRoundReg - 1;
        end
    endrule

    rule testOutput;
        let outStream = dut.outputStreamFifoOut.first;
        checkDataStream(outStream, "Output Stream");
        StreamSize concatSize = concatSizeReg + unpack(zeroExtend(convertByteEn2BytePtr(outStream.byteEn)));
        if (outStream.isLast) begin
            let ideaSize = ideaConcatSizeFifo.first;
            if (concatSize != ideaSize) begin
                $display("Error: ideaSize=%d, realSize=%d", ideaSize, concatSize);
                $finish();
            end 
            else begin
                // $display("INFO: verify output ideaSize=%d, realSize=%d, ideaLastSize=%d", ideaSize, concatSize, ideaSize%getMaxFrameSize());
                ideaConcatSizeFifo.deq;
                testFinishCntReg <= testFinishCntReg + 1;
            end
            concatSizeReg <= 0;
        end
        else begin
            concatSizeReg <= concatSize;
            if (outStream.data != getPseudoData()) begin
                $display("Error: Wrong output data");
                showDataStream(outStream);
                $finish();
            end
        end
        dut.outputStreamFifoOut.deq;
    endrule

    rule testFinish;
        if (testFinishCntReg == fromInteger(valueOf(TEST_NUM)-1)) begin
            $finish();
        end
    endrule

endmodule

(* doc = "testcase" *) 
module mkStreamSplitTb(Empty);

    StreamSplit dut <- mkStreamSplit;

    RandomStreamSize streamSizeRandomValue <- mkRandomStreamSize(fromInteger(valueOf(SEED_1)), fromInteger(valueOf(MAX_STREAM_SIZE_PTR)));
    RandomStreamSize splitLocationRandomValue <- mkRandomStreamSize(fromInteger(valueOf(SEED_2)), fromInteger(valueOf(MAX_STREAM_SIZE_PTR)-1));
    
    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testCntReg <- mkReg(0);
    Reg#(UInt#(32)) testRoundReg <- mkReg(0);

    FIFOF#(StreamSize) ideaTotalSizeFifo <- mkSizedFIFOF(valueOf(TEST_IDEAL_FIFO_DEPTH));
    FIFOF#(StreamSize) ideaSplitSizeFifo <- mkSizedFIFOF(valueOf(TEST_IDEAL_FIFO_DEPTH));

    Reg#(StreamSize) streamSize2PutReg <- mkReg(0);

    Reg#(Bool) hasRecvFirstChunkReg <- mkReg(False);
    Reg#(StreamSize) totalRecvSizeReg <- mkReg(0);

    rule testInit if (!isInitReg);
        isInitReg <= True;
        $display("INFO: ================start StreamSplitTb!==================");
    endrule

    rule testInput if (isInitReg && testCntReg < fromInteger(valueOf(TEST_NUM)));
        // First Frame
        if (streamSize2PutReg == 0) begin
            let size <- streamSizeRandomValue.next;
            let splitLocation <- splitLocationRandomValue.next;
            if (splitLocation < size) begin
                let isLast = size <= getMaxFrameSize();
                let firstSize = isLast ? size : getMaxFrameSize();
                let stream = generatePsuedoStream(firstSize, True, isLast);
                dut.splitLocationFifoIn.enq(splitLocation);
                dut.inputStreamFifoIn.enq(stream);
                ideaTotalSizeFifo.enq(size);
                ideaSplitSizeFifo.enq(splitLocation);
                streamSize2PutReg <= size - firstSize;
                // $display("INFO: Add input stream size %d, split at %d", size, splitLocation);
            end
        end
        else begin
            let isLast = streamSize2PutReg <= getMaxFrameSize();
            let size = isLast ? streamSize2PutReg : getMaxFrameSize();
            let stream = generatePsuedoStream(size, False, isLast);
            dut.inputStreamFifoIn.enq(stream);
            streamSize2PutReg <= streamSize2PutReg - size;
        end
    endrule

    rule testOutput if (isInitReg);
        let outStream = dut.outputStreamFifoOut.first;
        dut.outputStreamFifoOut.deq;
        checkDataStream(outStream, "split output stream");
        StreamSize totalSize = totalRecvSizeReg + unpack(zeroExtend(convertByteEn2BytePtr(outStream.byteEn)));
        
        if (outStream.isLast) begin
            if (hasRecvFirstChunkReg) begin
                if (totalSize != ideaTotalSizeFifo.first) begin
                    $display("Error: wrong total size, idea = %d, real = %d", ideaTotalSizeFifo.first, totalSize);
                    showDataStream(outStream);
                    $finish();
                end
                else begin
                    // $display("INFO: receive total size", totalSize);
                    ideaTotalSizeFifo.deq;
                    testCntReg <= testCntReg + 1;
                    hasRecvFirstChunkReg <= False;
                    totalRecvSizeReg <= 0;
                end
            end 
            else begin
                if (totalSize != ideaSplitSizeFifo.first) begin
                    $display("Error: wrong split location, idea = %d, real = %d", ideaSplitSizeFifo.first, totalSize);
                    showDataStream(outStream);
                    $finish();
                end
                else begin
                    // $display("INFO: receive first chunk at %d, total size %d", ideaSplitSizeFifo.first, ideaTotalSizeFifo.first);
                    ideaSplitSizeFifo.deq;
                    hasRecvFirstChunkReg <= True;
                    totalRecvSizeReg <= totalSize;
                end
            end
        end
        else begin
            totalRecvSizeReg <= totalSize;
        end
    endrule

    rule testFinish;
        if (testCntReg == fromInteger(valueOf(TEST_NUM)-1)) begin
            $finish();
        end
    endrule

endmodule