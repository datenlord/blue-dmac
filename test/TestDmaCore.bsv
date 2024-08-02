import GetPut::*;
import Randomizable::*;

import SemiFifo::*;
import PrimUtils::*;
import DmaTypes::*;
import DmaRequestCore::*;

typedef 100000 CHUNK_PER_EPOCH_TEST_NUM;
typedef 64'hFFFFFFFFFFFFFFFF MAX_ADDRESS;
typedef 16'hFFFF MAX_TEST_LENGTH;
typedef 2'b00 DEFAULT_TLP_SIZE_SETTING;
typedef 4   CHUNK_TX_TEST_SETTING_NUM;
typedef 6   CHUNK_RX_TEST_SETTING_NUM;

module mkChunkComputerTb(Empty);

    ChunkCompute dut <- mkChunkComputer(DMA_TX);

    Reg#(Bool)       isInitReg   <- mkReg(False);
    Reg#(UInt#(32))  testCntReg  <- mkReg(0); 
    Reg#(UInt#(32))  epochCntReg <- mkReg(0); 

    Reg#(DmaMemAddr) lenRemainReg <- mkReg(0);

    Randomize#(DmaMemAddr) startAddrRandomVal <- mkConstrainedRandomizer(0, fromInteger(valueOf(MAX_ADDRESS)-1));
    Randomize#(DmaMemAddr) lengthRandomVal    <- mkConstrainedRandomizer(1, fromInteger(valueOf(MAX_TEST_LENGTH)));

    function Bool hasBoundary(DmaRequest request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    rule testInit if (!isInitReg);
        startAddrRandomVal.cntrl.init;
        lengthRandomVal.cntrl.init;
        isInitReg <= True;
        dut.setTlpMaxSize.put(fromInteger(valueOf(DEFAULT_TLP_SIZE_SETTING)));
        $display("INFO: Start Test of mkChunkComputerTb");
        $display("INFO: Set Max Payload Size to ", valueOf(DEFAULT_TLP_SIZE));
    endrule

    rule testInput if (isInitReg && lenRemainReg == 0);
        DmaMemAddr testAddr <- startAddrRandomVal.next;
        DmaMemAddr testLength <- lengthRandomVal.next;
        let testEnd = testAddr + testLength - 1;
        if (testEnd > testAddr && testEnd <= fromInteger(valueOf(MAX_ADDRESS))) begin 
            let request = DmaRequest{
                startAddr: testAddr,
                length: testLength
            };
            lenRemainReg <= testLength;
            dut.dmaRequestFifoIn.enq(request);
            // $display("INFO: input ", fshow(request));
        end 
        else begin
            lenRemainReg <= 0;
        end 
    endrule

    rule testOutput if (isInitReg && lenRemainReg > 0);
        let newRequest = dut.chunkRequestFifoOut.first;
        dut.chunkRequestFifoOut.deq;
        immAssert(
            !hasBoundary(newRequest),
            "has boundary assert @ mkChunkComputerTb",
            fshow(newRequest)
        );
        let newRemain = lenRemainReg -  newRequest.length;
        lenRemainReg <= newRemain;
        if (newRemain == 0) begin
            if (epochCntReg < fromInteger(valueOf(CHUNK_PER_EPOCH_TEST_NUM)-1)) begin
                epochCntReg <= epochCntReg + 1;
            end 
            else begin
                epochCntReg <= 0;
                testCntReg <= testCntReg + 1;
                if (testCntReg == fromInteger(valueOf(CHUNK_TX_TEST_SETTING_NUM)-1)) begin
                    $display("INFO: ChunkComputer Test End.");
                    $finish();
                end 
                else begin
                    PcieTlpSizeSetting newSetting = fromInteger(valueOf(DEFAULT_TLP_SIZE_SETTING)) + truncate(pack(testCntReg)) + 1;
                    dut.setTlpMaxSize.put(newSetting);
                    $display("INFO: Set Max Payload Size to ", pack(fromInteger(valueOf(DEFAULT_TLP_SIZE)) << newSetting));
                end
            end
        end
    endrule

endmodule

typedef 'hABCD311 SIMPLE_TEST_ADDR ;
typedef 'h1111    SIMPLE_TEST_LEN  ;

(* doc = "testcase" *) 
module mkSimpleTestAlignedRqDescGen(Empty);
    AlignedDescGen dut <- mkAlignedRqDescGen;

    Reg#(Bool) isInitReg <- mkReg(False);

    rule testInit if (!isInitReg);
        isInitReg <= True;
        dut.reqFifoIn.enq(DmaRequest {
            startAddr: fromInteger(valueOf(SIMPLE_TEST_ADDR)),
            length   : fromInteger(valueOf(SIMPLE_TEST_LEN))
        });
    endrule

    rule testOutput if (isInitReg);
        let stream = dut.dataFifoOut.first;
        stream.deq;
        $display(fshow(stream));
        $finish();
    endrule

endmodule