import GetPut::*;
import Counter::*;
import FIFOF::*;
import BRAMFIFO::*;
import Vector::*;
import DReg::*;

import SemiFifo::*;

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
//  nSlot : slot numbers
//  nChunk: chunk numbers per slot
//  tChunk: chunk data types
interface CompletionFifo#(numeric type nSlot, type tChunk);
    interface Get#(SlotNum#(nSlot)) reserve;
    method    Bool available;
    interface FifoIn#(Tuple2#(SlotNum#(nSlot), tChunk)) append;
    interface Put#(SlotNum#(nSlot)) complete;
    interface FifoOut#(tChunk) drain;
endinterface

typedef Bit#(TLog#(nSlot)) SlotNum#(numeric type nSlot);

function Bool isPowerOf2(Integer n);
   return (n == (2 ** (log2(n))));
endfunction

module mkCompletionFifo#(Integer nChunk)(CompletionFifo#(nSlot, tChunk))
  provisos (Bits#(tChunk, szChunk), Log#(nSlot, ln), Add#(1, ln, ln1), Add#(1, _a, szChunk));

    let maxSlotIdx = fromInteger(valueOf(nSlot) - 1);
    function Action incrSlotIdx(Reg#(Bit#(ln)) idxReg);
        action
            if (isPowerOf2(valueOf(nSlot)))
                idxReg <= idxReg + 1;  // counter wraps automagically
            else
                idxReg <= ((idxReg == maxSlotIdx) ? 0 : idxReg + 1);
        endaction
    endfunction

    FIFOF#(Tuple2#(SlotNum#(nSlot), tChunk)) appendFifo <- mkFIFOF;
    FIFOF#(tChunk) drainFifo <- mkFIFOF;
    Vector#(nSlot, FIFOF#(tChunk)) bufferFifos <- replicateM(mkSizedBRAMFIFOF(nChunk));

    Reg#(SlotNum#(nSlot)) inIdxReg  <- mkReg(0);       // input index, return this value when `reserve` is called
    Reg#(SlotNum#(nSlot)) outIdxReg <- mkReg(0);       // output index, pipeout Fifos[outIdxReg] 
    Counter#(ln1) counter <- mkCounter(0);             // number of filled slots
    Reg#(Vector#(nSlot, Bool)) flagsReg <- mkReg(replicate(False));
    Reg#(Maybe#(SlotNum#(nSlot))) cmplSlotReg <- mkDReg(tagged Invalid);
    RWire#(SlotNum#(nSlot)) rstSlot  <- mkRWire;


    rule writeBuffer;
        let {slot, data} = appendFifo.first;
        appendFifo.deq;
        bufferFifos[slot].enq(data);
    endrule

    rule readBuffer;
        if (!bufferFifos[outIdxReg].notEmpty && flagsReg[outIdxReg]) begin  // complete assert and the buffer is empty
            incrSlotIdx(outIdxReg);
            rstSlot.wset(outIdxReg);
            counter.down;
        end
        else begin  
            let data = bufferFifos[outIdxReg].first;
            bufferFifos[outIdxReg].deq;
            drainFifo.enq(data);
        end
    endrule

    rule setFlags;
        let cmplMaybe = cmplSlotReg;
        let rstMaybe  = rstSlot.wget;
        let flags = flagsReg;
        if (isValid(cmplMaybe)) begin
            flags[fromMaybe(?, cmplMaybe)] = True;
        end
        if (isValid(rstMaybe)) begin
            flags[fromMaybe(?, rstMaybe)] = False;
        end
        flagsReg <= flags;
    endrule

    interface Get reserve;
        method ActionValue#(SlotNum#(nSlot)) get() if (counter.value <= maxSlotIdx);
            incrSlotIdx(inIdxReg);
            counter.up;
            return inIdxReg;
        endmethod
    endinterface

    method Bool available();
        return (counter.value <= maxSlotIdx);
    endmethod

    interface Put complete;
        method Action put(SlotNum#(nSlot) slot);
            cmplSlotReg <= tagged Valid slot;
        endmethod
    endinterface

    interface append = convertFifoToFifoIn(appendFifo);
    interface drain  = convertFifoToFifoOut(drainFifo);

endmodule
