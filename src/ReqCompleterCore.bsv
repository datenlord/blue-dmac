import FIFOF::*;
import GetPut :: *;
import Vector::*;

import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;
import PcieAxiStreamTypes::*;
import PrimUtils::*;
import StreamUtils::*;
import PcieDescriptorTypes::*;
import CompletionFifo::*;

function StraddleStream getEmptyStraddleStream();
    let sdStream = StraddleStream {
        data      : 0,
        byteEn    : 0,
        isDoubleFrame : False,
        isFirst   : replicate(False),
        isLast    : replicate(False),
        tag       : replicate(0),
        isCompleted : replicate(0)
    };
    return sdStream;
endfunction

function PcieRequesterCompleteDescriptor getDescriptorFromData(PcieTlpCtlIsSopPtr isSopPtr, Data data);
    if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_0))) begin
        return unpack(truncate(data));
    end
    else begin
        return unpack(truncate(data >> valueOf(STRADDLE_THRESH_BIT_WIDTH)));
    end
endfunction

function Data getStraddleData(PcieTlpCtlIsSopPtr isSopPtr, Data data);
    if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_0))) begin
        let sData = zeroExtend(Data'(data[valueOf(STRADDLE_THRESH_BIT_WIDTH)-1:0]));
    end
    else begin
        let sData = data >> valueOf(STRADDLE_THRESH_BIT_WIDTH);
    end
    return sData;
endfunction

function ByteEn getStraddleByteEn(PcieTlpCtlIsSopPtr isSopPtr, ByteEn byteEn);
    if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_0))) begin
        let sByteEn = zeroExtend(ByteEn'(byteEn[valueOf(STRADDLE_THRESH_BYTE_WIDTH)-1:0]));
    end
    else begin
        let sByteEn = byteEn >> valueOf(STRADDLE_THRESH_BYTE_WIDTH);
    end
    return sByteEn;
endfunction

function Bool isMyValidTlp(DmaPathNo path, PcieRequesterCompleteDescriptor desc);
    Bool valid = (desc.status == fromInteger(valueOf(SUCCESSFUL_CMPL))) && (!desc.isPoisoned);
    Bool pathMatch = (truncate(path) == desc.tag[valueOf(DES_NONEXTENDED_TAG_WIDTH) - 1]);
    return valid && pathMatch;
endfunction

interface RequesterCompleteCore;
    interface FifoIn#(StraddleStream) tlpFifoIn;
    interface FifoOut#(DataStream)    tlpFifoOut;
    interface FifoOut#(DataStream)    dataFifoOut;
    interface FifoIn#(DmaRequest)     rdReqFifoIn;
endinterface

module mkRequesterCompleteCore(RequesterCompleteCore);
    FIFOF#(StraddleStream) tlpInFifo      <- mkFIFOF;
    FIFOF#(DmaRequest)     reqInFifo      <- mkFIFOF;
    FIFOF#(DataStream)     tlpOutFifo     <- mkFIFOF;

    FIFOF#(SlotToken)      tagFifo        <- mkSizedFIFOF(4);      
    FIFOF#(Bool)           completedFifo  <- mkSizedFIFOF(4);      

    StreamPipe     descRemove     <- mkStreamHeaderRemove(fromInteger(valueOf(DES_RC_DESCRIPTOR_WIDTH))); 
    StreamPipe     streamReshape  <- mkStreamReshape;
    ChunkCompute   chunkSplitor   <- mkChunkComputer;
    CompletionFifo#(SLOT_PER_PATH, DataStream)  cBuffer <- mkCompletionFifo(valueOf(MAX_STREAM_NUM_PER_COMPLETION));
    
    Reg#(Bool) hasReadOnce <- mkReg(False);

    // Pipeline stage 1: convert StraddleStream to DataStream, may cost 2 cycle for one StraddleStream
    rule convertStraddleToDataStream;
        let sdStream = tlpInFifo.first;
        if (sdStream.isDoubleFrame) begin
            PcieTlpCtlIsSopPtr isSopPtr = 0;
            if (hasReadOnce) begin
                tlpInFifo.deq;
                hasReadOnce <= False;
                isSopPtr = 1;
            end
            else begin
                hasReadOnce <= True;
            end
            let stream = DataStream {
                data    : getStraddleData(isSopPtr, sdStream.data),
                byteEn  : getStraddleByteEn(isSopPtr, sideBand.dataByteEn);,
                isFirst : sdStream.isFirst[isSopPtr],
                isLast  : sdStream.isLast[isSopPtr]
            }
            let tag = sdStream.tag[isSopPtr];
            tagFifo.enq(tag);
        end
        else begin
            tlpInFifo.deq;
            hasReadOnce <= False;
            let stream = DataStream {
                data    : sdStream.data,
                byteEn  : sdStream.byteEn,
                isFirst : sdStream.isFirst[0],
                isLast  : sdStream.isLast[0]
            };
            let tag = sdStream.tag[0];
        end
        descRemove.streamFifoIn.enq(stream);
    endrule

    // Pipeline stage 2: remove the descriptor in the head of each TLP

    // Pipeline stage 3: Buffer the received DataStreams and reorder the,
    rule reorderStream;
        let stream = descRemove.streamFifoOut.first;
        let isCompleted = completedFifo.first;
        let tag = tagFifo.first;
        descRemove.streamFifoOut.deq;
        completedFifo.deq;
        tagFifo.deq;
        stream.isLast = isCompleted && stream.isLast;
        cBuffer.append.enq(tuple2(tag, stream));
        if (stream.isLast) begin
            cBuffer.complete.put(tag);
        end
    endrule

    // Pipeline stage 4: there may be bubbles in the first and last DataStream of a TLP because of RCB
    //  Reshape the DataStream and make sure it is continuous
    rule reshapeStream;
        let stream = cBuffer.drain.first;
        cBuffer.drain.deq;
        streamReshape.streamFifoIn.enq(stream);
    endrule

    // Pipeline stage 1: split to req to MRRS chunks
    rule reqSplit;
        let req = reqInFifo.first;
        reqInFifo.deq;
        chunkSplitor.dmaRequestFifoIn.enq(req);
    endrule

    // Pipeline stage 2: generate read descriptor
    rule cqDescGen;
        let req = chunkSplitor.chunkRequestFifoOut.first;
        chunkSplitor.chunkRequestFifoOut.deq;
        let tag <- completedFifo.reserve.get;
        let descriptor  = PcieRequesterRequestDescriptor {
            forceECRC       : False,
            attributes      : 0,
            trafficClass    : 0,
            requesterIdEn   : False,
            completerId     : 0,
            tag             : tag,
            requesterId     : 0,
            isPoisoned      : False,
            reqType         : fromInteger(valueOf(MEM_READ_REQ)),
            dwordCnt        : truncate(req.length >> valueOf(BYTE_DWORD_SHIFT_WIDTH)) + zeroExtend(DwordCount'(rq.length[1:0])),
            address         : truncate(req.startAddr >> valueOf(BYTE_DWORD_SHIFT_WIDTH)),
            addrType        : fromInteger(valueOf(TRANSLATED_ADDR))
        };
        let stream = DataStream {
            data    : zeroExtend(pack(descriptor)),
            byteEn  : convertBytePtr2ByteEn(fromInteger(valueOf(DES_RQ_DESCRIPTOR_WIDTH))),
            isFirst : True,
            isLast  : True
        };
        tlpOutFifo.enq(stream);
    endrule

    interface tlpFifoIn   = convertFifoToFifoIn(tlpInFifo);
    interface tlpFifoOut  = convertFifoToFifoOut(tlpOutFifo);
    interface rdReqFifoIn = convertFifoToFifoOut(reqInFifo);
    interface dataFifoOut = streamReshape.streamFifoOut;
endmodule
