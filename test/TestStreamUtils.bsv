import SemiFifo::*;
import Randomizable::*;
import StreamUtils::*;

typedef UInt#(32) StreamSize;
typedef 'hABABAB PSUEDO_DATA;
typedef 'hFFFF MAX_STREAM_SIZE;
typedef 'h1 MIN_STREAM_SIZE;
typedef 50 TEST_NUM;
typedef 'hFFFFFFFFFFFFFFFF MAX_BYTE_EN;


function Action showDataStream (DataStream stream);
    return action
        $display("Data = %b", stream.data);
        $display("byteEn = %b", stream.byteEn);
        $display("isFirst = %b, isLast = %b", stream.isFirst, stream.isLast);
    endaction;
endfunction

(* doc = "testcase" *) 
module mkStreamConcatTb(Empty);

    StreamConcat dut <- mkStreamConcat;

    Randomize#(StreamSize) streamASizeRandomValue <- mkConstrainedRandomizer(fromInteger(valueOf(MIN_STREAM_SIZE)), fromInteger(valueOf(MAX_STREAM_SIZE)));
    Randomize#(StreamSize) streamBSizeRandomValue <- mkConstrainedRandomizer(fromInteger(valueOf(MIN_STREAM_SIZE)), fromInteger(valueOf(MAX_STREAM_SIZE)));

    Reg#(StreamSize) streamASizeReg <- mkReg(0);
    Reg#(StreamSize) streamBSizeReg <- mkReg(0);
    Reg#(StreamSize) stramAframeCntReg <- mkReg(0);
    Reg#(StreamSize) stramBframeCntReg <- mkReg(0);
    
    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testCntReg <- mkReg(0);

    DataStream testStream = DataStream{
        data: 'b1010101010101010,
        byteEn: 'b11,
        isFirst: True,
        isLast: True
    };

    function DataStream generatePsuedoStream (StreamSize size, Bool isFirst);
        if (size < fromInteger(valueOf(BYTE_EN_WIDTH))) begin
            return DataStream{
                data: fromInteger(valueOf(PSUEDO_DATA)),
                byteEn: (1 << size) - 1,
                isFirst: isFirst,
                isLast: True
            };
        end 
        else begin
            return DataStream{
                data: fromInteger(valueOf(PSUEDO_DATA)),
                byteEn: fromInteger(valueOf(MAX_BYTE_EN)),
                isFirst: isFirst,
                isLast: False
            };
        end
    endfunction

    rule testInit if (!isInitReg);
        $display("INFO: start StreamConcatTb!");
        streamASizeRandomValue.cntrl.init;
        streamBSizeRandomValue.cntrl.init;
        isInitReg <= True;
    endrule

    rule testInput if (isInitReg && testCntReg < fromInteger(valueOf(TEST_NUM)));
        dut.inputStreamFirst.enq(testStream);
        dut.inputStreamSecond.enq(testStream);
        testCntReg <= testCntReg + 1;
    endrule

    rule testOutput;
        let outStream = dut.outputStream.first;
        showDataStream(outStream);
        dut.outputStream.deq;
    endrule
endmodule