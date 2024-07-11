import FIFOF::*;
import SemiFifo::*;
import Randomizable::*;
import StreamUtils::*;

typedef UInt#(32) StreamSize;
typedef 'hFFFFFFFFFFFFFFFF MAX_BYTE_EN;

typedef 'hAB PSEUDO_DATA;
typedef 8 PSEUDO_DATA_WIDTH;

typedef 'h1 MIN_STREAM_SIZE;

// TEST HYPER PARAMETERS CASE 1
// typedef 100 MAX_STREAM_SIZE;
// typedef 10 TEST_NUM;

// TEST HYPER PARAMETERS CASE 2
typedef 'hFFFF MAX_STREAM_SIZE;
typedef 1000 TEST_NUM;


(* doc = "testcase" *) 
module mkStreamConcatTb(Empty);

    StreamConcat dut <- mkStreamConcat;

    Randomize#(StreamSize) streamASizeRandomValue <- mkConstrainedRandomizer(fromInteger(valueOf(MIN_STREAM_SIZE)), fromInteger(valueOf(MAX_STREAM_SIZE)));
    Randomize#(StreamSize) streamBSizeRandomValue <- mkConstrainedRandomizer(fromInteger(valueOf(MIN_STREAM_SIZE)), fromInteger(valueOf(MAX_STREAM_SIZE)));

    Reg#(StreamSize) streamARemainSizeReg <- mkReg(0);
    Reg#(StreamSize) streamBRemainSizeReg <- mkReg(0);
    Reg#(StreamSize) concatSizeReg <- mkReg(0);

    FIFOF#(StreamSize) ideaConcatSizeFifo <- mkSizedFIFOF(10);
    
    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testCntReg <- mkReg(0);
    Reg#(UInt#(32)) testRoundReg <- mkReg(0);
    Reg#(UInt#(32)) testFinishCntReg <- mkReg(0);

    Data pseudoData = fromInteger(valueOf(PSEUDO_DATA));
    for (Integer idx = 0; idx < valueOf(TDiv#(DATA_WIDTH, PSEUDO_DATA_WIDTH)); idx = idx + 1) begin
        pseudoData = pseudoData | (pseudoData << idx*valueOf(PSEUDO_DATA_WIDTH));
    end

    function DataStream generatePsuedoStream (StreamSize size, Bool isFirst, Bool isLast);
        let offsetPtr = (fromInteger(valueOf(BYTE_EN_WIDTH)) - size) << valueOf(BYTE_WIDTH_WIDTH);
        Data streamData = (pseudoData << offsetPtr) >> offsetPtr;
        return DataStream{
            data: streamData,
            byteEn: (1 << size) - 1,
            isFirst: isFirst,
            isLast: isLast
        };
    endfunction

    rule testInit if (!isInitReg);
        $display("INFO: ================start StreamConcatTb!==================");
        $display(valueOf(BYTE_WIDTH_WIDTH));
        streamASizeRandomValue.cntrl.init;
        streamBSizeRandomValue.cntrl.init;
        isInitReg <= True;
    endrule

    rule testInput if (isInitReg && testCntReg < fromInteger(valueOf(TEST_NUM)));

        if (testRoundReg == 0 && dut.inputStreamFirst.notFull &&  dut.inputStreamSecond.notFull) begin
            StreamSize sizeA <- streamASizeRandomValue.next;
            StreamSize sizeB <- streamASizeRandomValue.next;
            ideaConcatSizeFifo.enq(sizeA + sizeB); 
            testRoundReg <= (sizeA + sizeB) / fromInteger(valueOf(BYTE_EN_WIDTH));
            let isLast = sizeA <= fromInteger(valueOf(BYTE_EN_WIDTH));
            let firstSizeA = isLast ? sizeA : fromInteger(valueOf(BYTE_EN_WIDTH));
            let firstSizeB = isLast ? sizeB : fromInteger(valueOf(BYTE_EN_WIDTH));
            dut.inputStreamFirst.enq(generatePsuedoStream(firstSizeA, True, isLast));
            dut.inputStreamSecond.enq(generatePsuedoStream(firstSizeB, True, isLast));
            streamARemainSizeReg <= sizeA - firstSizeA;
            streamBRemainSizeReg <= sizeB - firstSizeB;
            testCntReg <= testCntReg + 1;
            $display("INFO: Add Input of %d Epoch", testCntReg + 1);
            $display("INFO: streamASize = %d, streamBSize = %d, ideaSize = %d", sizeA, sizeB, sizeA+sizeB);
        end

        else if (testRoundReg > 0) begin
            if (streamARemainSizeReg > 0 && dut.inputStreamFirst.notFull) begin
                dut.inputStreamFirst.enq(generatePsuedoStream(streamARemainSizeReg, False, (streamARemainSizeReg <= fromInteger(valueOf(BYTE_EN_WIDTH)))));
                streamARemainSizeReg <= (streamARemainSizeReg > fromInteger(valueOf(BYTE_EN_WIDTH))) ? streamARemainSizeReg - fromInteger(valueOf(BYTE_EN_WIDTH)) : 0;
            end
            if (streamBRemainSizeReg > 0 && dut.inputStreamSecond.notFull) begin
                dut.inputStreamSecond.enq(generatePsuedoStream(streamBRemainSizeReg, False, (streamARemainSizeReg <= fromInteger(valueOf(BYTE_EN_WIDTH)))));
                streamBRemainSizeReg <= (streamBRemainSizeReg > fromInteger(valueOf(BYTE_EN_WIDTH))) ? streamBRemainSizeReg - fromInteger(valueOf(BYTE_EN_WIDTH)) : 0;
            end
            testRoundReg <= testRoundReg - 1;
        end

    endrule

    rule testOutput;
        let outStream = dut.outputStream.first;
        StreamSize concatSize = concatSizeReg + unpack(zeroExtend(convertByteEn2BytePtr(outStream.byteEn)));
        if (outStream.isLast) begin
            let ideaSize = ideaConcatSizeFifo.first;
            showDataStream(outStream);
            if (concatSize != ideaSize) begin
                $display("Error: ideaSize=%d, realSize=%d", ideaSize, concatSize);
                $finish();
            end 
            else begin
                $display("INFO: verify output ideaSize=%d, realSize=%d, ideaLastSize=%d", ideaSize, concatSize, ideaSize%fromInteger(valueOf(BYTE_EN_WIDTH)));
                ideaConcatSizeFifo.deq;
                testFinishCntReg <= testFinishCntReg + 1;
            end
            concatSizeReg <= 0;
        end
        else begin
            concatSizeReg <= concatSize;
        end
        dut.outputStream.deq;
    endrule

    rule testFinish;
        if (testFinishCntReg == fromInteger(valueOf(TEST_NUM)-1)) begin
            $finish();
        end
    endrule

endmodule