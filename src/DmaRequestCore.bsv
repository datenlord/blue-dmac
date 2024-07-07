import FIFOF::*;
import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;


typedef 4096 BUS_BOUNDARY;
typedef 12   BUS_BOUNDARY_WIDTH;

typedef struct {
    DmaRequestFrame dmaRequest;
    Maybe#(DmaMemAddr) firstChunkLen;
} ChunkRequestFrame deriving(Bits, Eq);                     

interface ChunkCompute;
    interface FifoIn#(DmaRequestFrame) dmaRequests;
    interface FifoOut#(DmaRequestFrame) chunkRequests;
endinterface 

module mkChunkComputer(ChunkCompute ifc);
    FIFOF#(DmaRequestFrame) inputFifo <- mkFIFOF;
    FIFOF#(DmaRequestFrame) outputFifo <- mkFIFOF;
    FIFOF#(ChunkRequestFrame) splitFifo <- mkFIFOF;

    Reg#(DmaMemAddr) newChunkPtrReg <- mkReg(0);
    Reg#(DmaMemAddr) totalLenRemainReg <- mkReg(0);
    Reg#(Bool) isSplittingReg <- mkReg(False);

    function Bool hasBoundary(DmaRequestFrame request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaRequestFrame request);
        // 4096 - startAddr % 4096
        Bit#(BUS_BOUNDARY_WIDTH) remainder = truncate(request.startAddr);
        Bit#(BUS_BOUNDARY_WIDTH) offset = fromInteger(valueOf(BUS_BOUNDARY)-1) - zeroExtend(remainder) + 1;
        return zeroExtend(offset);
    endfunction

    rule getfirstChunkLen;
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffset(request);
        // firstChunkLen = offset % PCIE_TLP_BYTES
        Bit#(PCIE_TLP_BYTES_WIDTH) offsetModTlpBytes = truncate(offset);
        DmaMemAddr firstLen = zeroExtend(offsetModTlpBytes);
        splitFifo.enq(ChunkRequestFrame {
            dmaRequest: request,
            firstChunkLen: hasBoundary(request) ? tagged Valid firstLen : tagged Invalid
        });
endrule

    rule execChunkSplit;
        let splitRequest = splitFifo.first;
        if (isSplittingReg) begin   // !isFirst
            if (totalLenRemainReg <= fromInteger(valueOf(PCIE_TLP_BYTES))) begin 
                isSplittingReg <= False; 
                outputFifo.enq(DmaRequestFrame {
                    startAddr: newChunkPtrReg,
                    length: totalLenRemainReg
                });
                splitFifo.deq;
                totalLenRemainReg <= 0;
            end else begin
                isSplittingReg <= True;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: newChunkPtrReg,
                    length: fromInteger(valueOf(PCIE_TLP_BYTES))
                });
                newChunkPtrReg <= newChunkPtrReg + fromInteger(valueOf(PCIE_TLP_BYTES));
                totalLenRemainReg <= totalLenRemainReg - fromInteger(valueOf(PCIE_TLP_BYTES));
            end
        end else begin   // isFirst
            let remainderLength = splitRequest.dmaRequest.length - fromMaybe(0, splitRequest.firstChunkLen);
            if (isValid(splitRequest.firstChunkLen)) begin
                Bool isSplittingNextCycle = (remainderLength > 0);
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr,
                    length: fromMaybe(0, splitRequest.firstChunkLen)
                });
                if (!isSplittingNextCycle) begin splitFifo.deq; end
                newChunkPtrReg <= splitRequest.dmaRequest.startAddr + fromMaybe(0, splitRequest.firstChunkLen);
                totalLenRemainReg <= remainderLength;
            end else begin
                Bool isSplittingNextCycle = (remainderLength > fromInteger(valueOf(PCIE_TLP_BYTES)));
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr,
                    length: fromInteger(valueOf(PCIE_TLP_BYTES))
                });
                if (!isSplittingNextCycle) begin  splitFifo.deq; end
                newChunkPtrReg <= splitRequest.dmaRequest.startAddr + fromInteger(valueOf(PCIE_TLP_BYTES));
                totalLenRemainReg <= remainderLength - fromInteger(valueOf(PCIE_TLP_BYTES));
            end
        end
    endrule

    interface  dmaRequests = convertFifoToFifoIn(inputFifo);
    interface  chunkRequests = convertFifoToFifoOut(outputFifo);
endmodule