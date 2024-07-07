import SemiFifo::*;
import Randomizable::*;
import DmaTypes::*;
import DmaRequestCore::*;

typedef 50 TEST_NUM;
typedef 64'hFFFFFFFFFFFFFFFF MAX_ADDRESS;
typedef 32'hFFFFFFFF MAX_TEST_LENGTH;

(* doc = "testcase" *) 
module mkChunkComputerTb (Empty);

    ChunkCompute dut <- mkChunkComputer;

    Reg#(Bool) isInitReg <- mkReg(False);
    Reg#(UInt#(32)) testCntReg <- mkReg(0); 
    Reg#(DmaMemAddr) lenRemainReg <- mkReg(0);
    Reg#(DmaRequestFrame) testRequest <- mkRegU;
    Randomize#(DmaMemAddr) startAddrRandomVal <- mkConstrainedRandomizer(0, fromInteger(valueOf(MAX_ADDRESS)-1));
    Randomize#(DmaMemAddr) lengthRandomVal <- mkConstrainedRandomizer(1, fromInteger(valueOf(MAX_TEST_LENGTH)));

    function Bool hasBoundary(DmaRequestFrame request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    function Action showRequest (DmaRequestFrame request);
        return action
            $display("startAddr: ", request.startAddr, " length: ", request.length);
        endaction;
    endfunction

    rule testInit if (!isInitReg);
        startAddrRandomVal.cntrl.init;
        lengthRandomVal.cntrl.init;
        isInitReg <= True;
        $display("Start Test of mkChunkComputerTb");
    endrule

    rule testInput if (isInitReg && lenRemainReg == 0);
        DmaMemAddr testAddr <- startAddrRandomVal.next;
        DmaMemAddr testLength <- lengthRandomVal.next;
        let testEnd = testAddr + testLength - 1;
        if (testEnd > testAddr && testEnd <= fromInteger(valueOf(MAX_ADDRESS))) begin 
            let request = DmaRequestFrame{
                startAddr: testAddr,
                length: testLength
            };
            lenRemainReg <= testLength;
            dut.dmaRequests.enq(request);
            showRequest(request);
        end else begin
            lenRemainReg <= 0;
        end 
    endrule

    rule testOutput if (isInitReg && lenRemainReg > 0);
        let newRequest = dut.chunkRequests.first;
        dut.chunkRequests.deq;
        if (hasBoundary(newRequest)) begin
            $display("Error, has 4KB boundary!");
            showRequest(newRequest);
            $finish();
        end else begin
            // showRequest(newRequest);
            let newRemain = lenRemainReg -  newRequest.length;
            lenRemainReg <= newRemain;
            if(newRemain == 0) begin
                testCntReg <= testCntReg + 1;
            end
        end
    endrule

    rule testFinish ;
        if (testCntReg == fromInteger(valueOf(TEST_NUM))) $finish();
    endrule
endmodule