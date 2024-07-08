import FIFOF::*;
import GetPut :: *;
import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;


typedef 4096                                BUS_BOUNDARY;
typedef TLog#(TAdd#(1, BUS_BOUNDARY))       BUS_BOUNDARY_WIDTH;
typedef Bit#(BUS_BOUNDARY_WIDTH)            PcieTlpMaxMaxSize;
typedef Bit#(TLog#(BUS_BOUNDARY_WIDTH))     PcieTlpSizeWidth;
typedef 128                                 DEFAULT_TLP_SIZE;
typedef TLog#(TAdd#(1, DEFAULT_TLP_SIZE))   DEFAULT_TLP_SIZE_WIDTH;
typedef 3                                   PCIE_TLP_SIZE_SETTING_WIDTH;
typedef Bit#(PCIE_TLP_SIZE_SETTING_WIDTH)   PcieTlpSizeSetting;      
typedef enum {DMA_RX, DMA_TX}               TRXDirection deriving(Bits, Eq);
                

typedef struct {
    DmaRequestFrame dmaRequest;
    Maybe#(DmaMemAddr) firstChunkLenMaybe;
} ChunkRequestFrame deriving(Bits, Eq);                     

interface ChunkCompute;
    interface FifoIn#(DmaRequestFrame)  dmaRequests;
    interface FifoOut#(DmaRequestFrame) chunkRequests;
    interface Put#(PcieTlpSizeSetting)  setTlpMaxSize;
endinterface 

module mkChunkComputer (TRXDirection direction, ChunkCompute ifc);
    FIFOF#(DmaRequestFrame) inputFifo <- mkFIFOF;
    FIFOF#(DmaRequestFrame) outputFifo <- mkFIFOF;
    FIFOF#(ChunkRequestFrame) splitFifo <- mkFIFOF;
    Reg#(DmaMemAddr) tlpMaxSize <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));                   //MPS if isTX, MRRS else
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidth <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   
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
        Bit#(BUS_BOUNDARY_WIDTH) offset = fromInteger(valueOf(BUS_BOUNDARY) - 1) - zeroExtend(remainder) + 1;
        return zeroExtend(offset);
    endfunction

    rule getfirstChunkLen;
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffset(request);
        // firstChunkLen = offset % PCIE_TLP_BYTES
        DmaMemAddr firstLen = zeroExtend(PcieTlpMaxMaxSize'(offset[tlpMaxSizeWidth-1:0]));
        splitFifo.enq(ChunkRequestFrame {
            dmaRequest: request,
            firstChunkLenMaybe: hasBoundary(request) ? tagged Valid firstLen : tagged Invalid
        });
    endrule

    rule execChunkSplit;
        let splitRequest = splitFifo.first;
        if (isSplittingReg) begin   // !isFirst
            if (totalLenRemainReg <= tlpMaxSize) begin 
                isSplittingReg <= False; 
                outputFifo.enq(DmaRequestFrame {
                    startAddr: newChunkPtrReg,
                    length: totalLenRemainReg
                });
                splitFifo.deq;
                totalLenRemainReg <= 0;
            end 
            else begin
                isSplittingReg <= True;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: newChunkPtrReg,
                    length: tlpMaxSize
                });
                newChunkPtrReg <= newChunkPtrReg + tlpMaxSize;
                totalLenRemainReg <= totalLenRemainReg - tlpMaxSize;
            end
        end 
        else begin   // isFirst
            let remainderLength = splitRequest.dmaRequest.length - fromMaybe(0, splitRequest.firstChunkLenMaybe);
            if (isValid(splitRequest.firstChunkLenMaybe)) begin
                Bool isSplittingNextCycle = (remainderLength > 0);
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr,
                    length: fromMaybe(0, splitRequest.firstChunkLenMaybe)
                });
                if (!isSplittingNextCycle) begin 
                    splitFifo.deq; 
                end
                newChunkPtrReg <= splitRequest.dmaRequest.startAddr + fromMaybe(0, splitRequest.firstChunkLenMaybe);
                totalLenRemainReg <= remainderLength;
            end 
            else begin
                Bool isSplittingNextCycle = (remainderLength > tlpMaxSize);
                isSplittingReg <= isSplittingNextCycle;
                outputFifo.enq(DmaRequestFrame {
                    startAddr: splitRequest.dmaRequest.startAddr,
                    length: tlpMaxSize
                });
                if (!isSplittingNextCycle) begin  
                    splitFifo.deq; 
                end
                newChunkPtrReg <= splitRequest.dmaRequest.startAddr + tlpMaxSize;
                totalLenRemainReg <= remainderLength - tlpMaxSize;
            end
        end
    endrule

    interface  dmaRequests = convertFifoToFifoIn(inputFifo);
    interface  chunkRequests = convertFifoToFifoOut(outputFifo);

    interface Put setTlpMaxSize;
        method Action put (PcieTlpSizeSetting tlpSizeSetting);
            let setting = tlpSizeSetting;
            setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1] = (direction == DMA_TX) ? 0 : setting[valueOf(PCIE_TLP_SIZE_SETTING_WIDTH)-1];
            DmaMemAddr defaultTlpMaxSize = fromInteger(valueOf(DEFAULT_TLP_SIZE));
            tlpMaxSize <= DmaMemAddr'(defaultTlpMaxSize << setting);
            PcieTlpSizeWidth defaultTlpMaxSizeWidth = fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH));
            tlpMaxSizeWidth <= PcieTlpSizeWidth'(defaultTlpMaxSizeWidth + zeroExtend(setting));
        endmethod
    endinterface
endmodule