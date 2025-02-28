import GetPut::*;
import Counter::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import DReg::*;
import Connectable::*;
import BRAM :: *;
import CpltBufferCf :: *;

import SemiFifo::*;



typedef struct {
    Bit#(TLog#(nChunk)) curChunkIdx;
} CpltFifoMetaEntry#(numeric type nChunk) deriving (Bits, FShow);

// CompletionFifo
//
// A CompletionFifo is like a CompletionBuffer
// but uses Fifos instead of RegFile.
// CompletionFifo can reorder interlaced chunks belong to different streams.

// Example
// reserve a token    : slot = CRam.reserve.get;
// receive a chunk    : CRam.append.enq(tuple2(slot, chunk));
// all chunks received: CRam.complete.put(slot);
// get chunks in order: CRam.drain.first; CRam.drain.deq;

// Parameters:
//  nSlot : slot numbers, should be less than 16 in current version
//  nChunk: chunk numbers per slot, a large value may cause bad timing
//  tChunk: chunk data types
interface CompletionFifo#(numeric type nSlot, numeric type nChunk, type tChunk);
    interface Get#(SlotNum#(nSlot)) reserve;
    method    Bool available;
    interface FifoIn#(Tuple3#(SlotNum#(nSlot), tChunk, Bool)) append;
    interface FifoOut#(tChunk) drain;
endinterface

typedef Bit#(TLog#(nSlot)) SlotNum#(numeric type nSlot);
typedef Bit#(TAdd#(TLog#(nSlot), TLog#(nChunk))) CpltFifoInternalBufferAddress#(numeric type nSlot, numeric type nChunk);

function Bool isPowerOf2(Integer n);
   return (n == (2 ** (log2(n))));
endfunction

module mkCompletionFifo(CompletionFifo#(nSlot, nChunk, tChunk))
    provisos (
        Bits#(tChunk, szChunk), Add#(1, _a, szChunk), Add#(_b, TLog#(nSlot), 4),
        Alias#(CpltFifoInternalBufferAddress#(nSlot, nChunk), tStorageAddr)
    );


    let maxSlotIdx = fromInteger(valueOf(nSlot) - 1);

    FIFOF#(Tuple3#(SlotNum#(nSlot), tChunk, Bool)) appendFifo <- mkFIFOF;
    FIFOF#(tChunk) drainFifo <- mkFIFOF;


    BRAM2Port#(SlotNum#(nSlot), CpltFifoMetaEntry#(nChunk)) metaStorage <- mkBRAM2Server(defaultValue);

    BRAM2Port#(tStorageAddr, tChunk) chunkStorage <- mkBRAM2Server(defaultValue);

    CompletionBuf#(nSlot, CpltFifoMetaEntry#(nChunk)) cpltFlagBuffer <- mkCompletionBuf;
    
    Counter#(TAdd#(1, TLog#(nSlot))) counter <- mkCounter(0);             // number of filled slots

    // Pipeline FIFOs:
    FIFOF#(Tuple3#(SlotNum#(nSlot), tChunk, Bool)) handleMeatStorageRespPipelineQueue <- mkSizedFIFOF(4);
    FIFOF#(CpltFifoMetaEntry#(nChunk)) pendingOutputPipelineQueue <- mkFIFOF;

    rule forwardDrain;
        cpltFlagBuffer.deq;
        pendingOutputPipelineQueue.enq(cpltFlagBuffer.first);
    endrule
   
    rule handleWriteStepOne;
        let {slot, data, isAllCplt} = appendFifo.first;
        appendFifo.deq;

        let bramReq = BRAMRequest {
            write   : False,
            responseOnWrite : False,
            address : slot,
            datain  : ?
        };
        metaStorage.portA.request.put(bramReq);
        handleMeatStorageRespPipelineQueue.enq(tuple3(slot, data, isAllCplt));
    endrule

    rule handleMetaStorageResp;
        let {slot, data, isAllCplt} = handleMeatStorageRespPipelineQueue.first;
        handleMeatStorageRespPipelineQueue.deq;

        let meta <- metaStorage.portA.response.get;

        
        tStorageAddr storageAddr = unpack({pack(slot), pack(meta.curChunkIdx)});

        let writeBackMeta = CpltFifoMetaEntry {
            curChunkIdx: isAllCplt ? 0 : meta.curChunkIdx + 1
        }; 

        let bramReqForMeta = BRAMRequest {
            write   : True,
            responseOnWrite : False,
            address : slot,
            datain  : writeBackMeta
        };
        metaStorage.portB.request.put(bramReqForMeta);

        let bramReqForChunk = BRAMRequest {
            write   : True,
            responseOnWrite : False,
            address : storageAddr,
            datain  : data
        };
        chunkStorage.portB.request.put(bramReqForChunk);

        if (isAllCplt) begin
            cpltFlagBuffer.complete(tuple2(slot, meta));
        end


    endrule

    Reg#(CpltFifoMetaEntry#(nChunk)) curOutputSlotMetaReg <- mkReg(CpltFifoMetaEntry{curChunkIdx: 0});
    Reg#(SlotNum#(nSlot)) curOutputSlotIdxReg <- mkReg(0);
    rule handleFinalOutput;
        let meta = pendingOutputPipelineQueue.first;
        
        let isFinished = meta.curChunkIdx == curOutputSlotMetaReg.curChunkIdx;
        let isFirst = curOutputSlotMetaReg.curChunkIdx == 0;

        if (isFinished) begin
            pendingOutputPipelineQueue.deq;
            // mark next as First
            curOutputSlotMetaReg <= CpltFifoMetaEntry { curChunkIdx: 0 };
            curOutputSlotIdxReg <= curOutputSlotIdxReg + 1;
            counter.down;
        end

        let zeroBasedChunkCnt = meta.curChunkIdx;
        tStorageAddr storageAddr = unpack({pack(curOutputSlotIdxReg), pack(curOutputSlotMetaReg.curChunkIdx)});
        let bramReqForChunk = BRAMRequest {
            write   : False,
            responseOnWrite : False,
            address : storageAddr,
            datain  : ?
        };
        chunkStorage.portA.request.put(bramReqForChunk);
    endrule

    rule forwardFinalOutput;
        let chunk <- chunkStorage.portA.response.get;
        drainFifo.enq(chunk);
    endrule


    interface Get reserve;
        method ActionValue#(SlotNum#(nSlot)) get();
            let slotId <- cpltFlagBuffer.reserve;
            counter.up;
            return slotId;
        endmethod
    endinterface

    method Bool available();
        return (counter.value <= maxSlotIdx);
    endmethod


    interface append = convertFifoToFifoIn(appendFifo);
    interface drain  = convertFifoToFifoOut(drainFifo);

endmodule