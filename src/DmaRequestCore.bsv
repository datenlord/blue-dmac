import FIFOF::*;
import PcieTypes::*;
import DmaTypes::*;

typedef 4096 BUS_BOUNDARY
typedef 12   BUS_BOUNDARY_WIDTH

typedef struct {
    DmaRequestFrame dmaRequest;
    Maybe#(DmaMemAddr) firstChunkLen;
} ChunkRequestFrame deriving(Bits, Eq);                     

Interface ChunkCompute;
    FifoIn#(DmaRequestFrame) dmaRequests;
    FifoOut#(DmaRequestFrame) chunkRequests;
endinterface 

module mkChunkComputer(ChunkCompute ifc);
    FIFOF#(DmaRequestFrame) inputFifo <- mkFIFOF;
    FIFOF#(DmaRequestFrame) outputFifo <- mkFIFOF;
    FIFOF#(ChunkRequestFrame) splitFifo <- mkFIFOF;

    Reg#(DmaMemAddr) newChunkPtrReg <- mkReg(0);
    Reg#(DmaMemAddr) totalLenRemainReg <- mkReg(0);
    Reg#(Bool) isSplittigReg <- mkReg(False);

    function Bool hasBoundary(DmaRequestFrame request);
        let highIdx = (request.startAddr + request.length) >> BUS_BOUNDARY_WIDTH;
        let lowIdx = request.startAddr >> BUS_BOUNDARY_WIDTH;
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaRequestFrame request);
        DmaMemAddr offset = zeroExtend(fromInteger(valueOf(BUS_BOUNDARY)) - pack(request.startAddr[BUS_BOUNDARY_WIDTH-1:0]));
        return offset;
    endfunction

    rule getfirstChunkLen if(inputFifo.notEmpty && splitFifo.notFull);
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffSet(request);
        // firstChunkLen = offset % PCIE_TLP_BYTES
        DmaMemAddr firstLen = zeroExtend(offset[valueOf(PCIE_TLP_BYTES_WIDTH)-1:0]);
        ChunkRequestFrame splitRequest = {
            dmaRequest: request,
            firstChunkLen: hasBoundary(request) ? tagged Valid firstLen : tagged Invalid; 
        }
        splitFifo.enq(splitRequest);
    endrule

    rule execSplit if(splitFifo.notEmpty && outFifo.notFull);
        let splitRequest = splitFifo.first;
        if (isSplittingReg) begin
                if (totalLenRemainReg <= PCIE_TLP_BYTES) begin 
                    isSplittingReg <= False; 
                    outputFifo.enq(DmaRequestFrame {
                        startAddr: newChunkPtrReg;
                        length: totalLenRemainReg;
                    });
                    splitFifo.deq;
                    totalLenRemainReg <= 0;
                end else begin
                    isSplittingReg <= True;
                    outputFifo.enq(DmaRequestFrame {
                        startAddr: newChunkPtrReg;
                        length: fromInteger(valueOf(PCIE_TLP_BYTES));
                    });
                    newChunkPtrReg <= newChunkPtrReg + fromInteger(valueOf(PCIE_TLP_BYTES));
                    totalLenRemainReg <= totalLenRemainReg - PCIE_TLP_BYTES;
                end
        end else begin
            let remainderLength = splitRequest.dmaRequest.length - fromMaybe(0, splitRequest.firstChunkLen);
            if (isValid(splitRequest.firstChunkLen)) begin
                Bool isSplittingNextCycle = (remainderLength > 0);
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr;
                    length: fromMaybe(0, splitRequest.firstChunkLen);
                });
                if (!isSplittingNextCycle) begin splitFifo.deq; end; 
                newChunkPtrReg <= splitRequest.dmaRequest + fromMaybe(0, splitRequest.firstChunkLen);
                totalLenRemainReg <= remainderLength;
            end else begin
                Bool isSplittingNextCycle = (remainderLength > PCIE_TLP_BYTES);
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr;
                    length: fromInteger(valueOf(PCIE_TLP_BYTES));
                });
                if (!isSplittingNextCycle) begin  splitFifo.deq; end
                newChunkPtrReg <= newChunkPtrReg + fromInteger(valueOf(PCIE_TLP_BYTES));
                totalLenRemainReg <= remainderLength - PCIE_TLP_BYTES;
            end
        end
    endrule

    interface  dmaRequests = convertFifoToFifoOut(inputFifo);
    interface  chunkRequests = convertFifoToFifoOut(outputFifo);
endmodule