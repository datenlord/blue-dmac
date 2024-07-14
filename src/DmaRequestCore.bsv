import FIFOF::*;
import GetPut :: *;

import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;


typedef 4096                                BUS_BOUNDARY;
typedef TAdd#(1, TLog#(BUS_BOUNDARY))       BUS_BOUNDARY_WIDTH;

typedef Bit#(BUS_BOUNDARY_WIDTH)            PcieTlpMaxMaxPayloadSize;
typedef Bit#(TLog#(BUS_BOUNDARY_WIDTH))     PcieTlpSizeWidth;

typedef 128                                 DEFAULT_TLP_SIZE;
typedef TAdd#(1, TLog#(DEFAULT_TLP_SIZE))   DEFAULT_TLP_SIZE_WIDTH;

typedef 3                                   PCIE_TLP_SIZE_SETTING_WIDTH;
typedef Bit#(PCIE_TLP_SIZE_SETTING_WIDTH)   PcieTlpSizeSetting;      

typedef struct {
    DmaRequestFrame dmaRequest;
    DmaMemAddr firstChunkLen;
} ChunkRequestFrame deriving(Bits, Eq);                     

interface ChunkCompute;
    interface FifoIn#(DmaRequestFrame)  dmaRequestFifoIn;
    interface FifoOut#(DmaRequestFrame) chunkRequestFifoOut;
    interface Put#(PcieTlpSizeSetting)  setTlpMaxSize;
endinterface 

module mkChunkComputer (TRXDirection direction, ChunkCompute ifc);

    FIFOF#(DmaRequestFrame)   inputFifo  <- mkFIFOF;
    FIFOF#(DmaRequestFrame)   outputFifo <- mkFIFOF;
    FIFOF#(ChunkRequestFrame) splitFifo  <- mkFIFOF;

    Reg#(DmaMemAddr) newChunkPtrReg      <- mkReg(0);
    Reg#(DmaMemAddr) totalLenRemainReg   <- mkReg(0);
    Reg#(Bool)       isSplittingReg      <- mkReg(False);
    
    Reg#(DmaMemAddr)       tlpMaxSize      <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE)));
    Reg#(PcieTlpSizeWidth) tlpMaxSizeWidth <- mkReg(fromInteger(valueOf(DEFAULT_TLP_SIZE_WIDTH)));   

    function Bool hasBoundary(DmaRequestFrame request);
        let highIdx = (request.startAddr + request.length - 1) >> valueOf(BUS_BOUNDARY_WIDTH);
        let lowIdx = request.startAddr >> valueOf(BUS_BOUNDARY_WIDTH);
        return (highIdx > lowIdx);
    endfunction

    function DmaMemAddr getOffset(DmaRequestFrame request);
        // MPS - startAddr % MPS, MPS means MRRS when the module is set to RX mode
        DmaMemAddr remainderOfMps = zeroExtend(PcieTlpMaxMaxPayloadSize'(request.startAddr[tlpMaxSizeWidth-1:0]));
        DmaMemAddr offsetOfMps = tlpMaxSize - remainderOfMps;    
        return offsetOfMps;
    endfunction

    rule getfirstChunkLen;
        let request = inputFifo.first;
        inputFifo.deq;
        let offset = getOffset(request);
        let firstLen = (request.length > tlpMaxSize) ? tlpMaxSize : request.length;
        splitFifo.enq(ChunkRequestFrame {
            dmaRequest: request,
            firstChunkLen: hasBoundary(request) ? offset : firstLen
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
            let remainderLength = splitRequest.dmaRequest.length - splitRequest.firstChunkLen;
            Bool isSplittingNextCycle = (remainderLength > 0);
            isSplittingReg <= isSplittingNextCycle;
            outputFifo.enq(DmaRequestFrame {
                startAddr: splitRequest.dmaRequest.startAddr,
                length: splitRequest.firstChunkLen
            }); 
            if (!isSplittingNextCycle) begin 
                splitFifo.deq; 
            end
            newChunkPtrReg <= splitRequest.dmaRequest.startAddr + splitRequest.firstChunkLen;
            totalLenRemainReg <= remainderLength;
        end
    endrule

    interface  dmaRequestFifoIn = convertFifoToFifoIn(inputFifo);
    interface  chunkRequestFifoOut = convertFifoToFifoOut(outputFifo);

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