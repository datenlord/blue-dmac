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

typedef 64  CMPL_NPREQ_INFLIGHT_NUM;
typedef 20  CMPL_NPREQ_WAITING_CLKS;
typedef 2'b11 NP_CREDIT_INCREMENT;
typedef 2'b00 NP_CREDIT_NOCHANGE;

typedef 3 BYTEEN_INFIFO_DEPTH;

typedef 'h1F IDEA_CQ_TKEEP_OF_CSR;
typedef 'hF  IDEA_CC_TKEEP_OF_CSR;

// Support Straddle in RQ/RC
interface RequesterAxiStreamAdapter;
    // Dma To Adapter DataStreams
    interface Vector#(DMA_PATH_NUM, FifoIn#(DataStream))     dmaDataFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoIn#(SideBandByteEn)) dmaSideBandFifoIn;
    // Adapter To Dma StraddleStreams, which may contains 2 TLP
    interface Vector#(DMA_PATH_NUM, FifoOut#(StraddleStream)) dmaDataFifoOut;
    // C2H RQ AxiStream Master
    (* prefix = "" *) interface RawPcieRequesterRequest rawRequesterRequest;
    // C2H RC AxiStream Slave
    (* prefix = "" *) interface RawPcieRequesterComplete rawRequesterComplete;
endinterface

// TODO: optimize fully-pipeline performance
(* synthesize *)
module mkRequesterAxiStreamAdapter(RequesterAxiStreamAdapter);
    ConvertDataStreamsToStraddleAxis dmaToAxisConverter <- mkConvertDataStreamsToStraddleAxis;
    ConvertStraddleAxisToDataStream  axisToDmaConverter <- mkConvertStraddleAxisToDataStream;

    Vector#(DMA_PATH_NUM, FifoIn#(DataStream))       dmaDataFifoInIfc      = newVector;
    Vector#(DMA_PATH_NUM, FifoIn#(SideBandByteEn))   dmaSideBandFifoInIfc  = newVector;
    Vector#(DMA_PATH_NUM, FifoOut#(StraddleStream))  dmaFifoOutIfc         = newVector;

    let rawAxiStreamSlaveIfc  <- mkFifoInToRawPcieAxiStreamSlave(axisToDmaConverter.axiStreamFifoIn);
    let rawAxiStreamMasterIfc <- mkFifoOutToRawPcieAxiStreamMaster(dmaToAxisConverter.axiStreamFifoOut);

    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        dmaDataFifoInIfc[pathIdx]     = dmaToAxisConverter.dataFifoIn[pathIdx];
        dmaSideBandFifoInIfc[pathIdx] = dmaToAxisConverter.byteEnFifoIn[pathIdx];
        dmaFifoOutIfc[pathIdx]        = axisToDmaConverter.dataFifoOut[pathIdx];
    end

    interface dmaDataFifoIn     = dmaDataFifoInIfc;
    interface dmaSideBandFifoIn = dmaSideBandFifoInIfc;
    interface dmaDataFifoOut    = dmaFifoOutIfc;

    interface RawPcieRequesterRequest rawRequesterRequest;
        interface rawAxiStreamMaster = rawAxiStreamMasterIfc;
        method Action pcieProgressTrack(
            Bool            tagValid0,
            Bool            tagValid1,
            PcieRqTag       tag0,
            PcieRqTag       tag1,
            Bool            seqNumValid0,
            Bool            seqNumValid1,
            PcieRqSeqNum    seqNum0,
            PcieRqSeqNum    seqNum1
            );
            // Not support progress track now
        endmethod
    endinterface

    interface RawPcieRequesterComplete rawRequesterComplete;
        interface rawAxiStreamSlave = rawAxiStreamSlaveIfc;
    endinterface
endmodule

// Do not support straddle in CQ/CC
interface CompleterAxiStreamAdapter;
    // Adapter To Dma DataStream
    interface FifoOut#(DataStream) dmaDataFifoOut;
    // Dma To Adapter DataStreams
    interface FifoIn#(DataStream)  dmaDataFifoIn;
    // H2C CQ AxiStream Slave
    (* prefix = "" *) interface RawPcieCompleterRequest  rawCompleterRequest;
    // H2C CC AxiStream Master
    (* prefix = "" *) interface RawPcieCompleterComplete rawCompleterComplete;
endinterface

// Completer Only Receives and Transmits One Beat TLP, in which isFirst = isLast = True
(* synthesize *)
module mkCompleterAxiStreamAdapter(CompleterAxiStreamAdapter);
    FIFOF#(DataStream) inFifo  <- mkFIFOF;
    FIFOF#(DataStream) outFifo <- mkFIFOF;
    FIFOF#(CmplReqAxiStream)  reqInFifo   <- mkFIFOF;
    FIFOF#(CmplCmplAxiStream) cmplOutFifo <- mkFIFOF;

    Reg#(Bool) isInPacketReg <- mkReg(False);

    let rawAxiStreamSlaveIfc  <- mkFifoInToRawPcieAxiStreamSlave(convertFifoToFifoIn(reqInFifo));
    let rawAxiStreamMasterIfc <- mkFifoOutToRawPcieAxiStreamMaster(convertFifoToFifoOut(cmplOutFifo));

    rule genAxis;
        // Straddle mode is disable of completer
        let stream = inFifo.first;
        inFifo.deq;
        if (stream.isFirst && stream.isLast) begin
            let isSop = PcieTlpCtlIsSopCommon {
                isSopPtrs : replicate(0),  
                isSop     : 1 
            };
            let isEop = PcieTlpCtlIsEopCommon {
                isEopPtrs : replicate(0), 
                isEop     : 1
            };
            // Do not enable parity check in the core
            let sideBand = PcieCompleterCompleteSideBandFrame {
                parity      : 0,  
                discontinue : False,
                isSop       : isSop,
                isEop       : isEop
            };
            let axiStream = CmplCmplAxiStream {
                tData : stream.data,
                tKeep : fromInteger(valueOf(IDEA_CC_TKEEP_OF_CSR)),
                tLast : True,
                tUser : pack(sideBand)
            };
            cmplOutFifo.enq(axiStream);
        end
    endrule

    rule parseAxis;
        let axiStream = reqInFifo.first;
        reqInFifo.deq;
        isInPacketReg <= !axiStream.tLast;
        // First Beat
        if (!isInPacketReg && axiStream.tLast) begin
            PcieCompleterRequestSideBandFrame sideBand = unpack(axiStream.tUser);
            let stream = DataStream {
                data    : axiStream.tData,
                byteEn  : sideBand.dataByteEn,
                isFirst : True,
                isLast  : True
            };
            outFifo.enq(stream);
        end
    endrule

    interface dmaDataFifoOut = convertFifoToFifoOut(outFifo);
    interface dmaDataFifoIn  = convertFifoToFifoIn(inFifo);

    interface RawPcieCompleterRequest rawCompleterRequest;
        interface rawAxiStreamSlave = rawAxiStreamSlaveIfc;
        method PcieNonPostedRequst nonPostedReqCreditIncrement = fromInteger(valueOf(NP_CREDIT_INCREMENT));
        method Action nonPostedReqCreditCnt(PcieNonPostedRequstCount nonPostedpReqCount);
        endmethod
    endinterface

    interface RawPcieCompleterComplete rawCompleterComplete;
        interface rawAxiStreamMaster = rawAxiStreamMasterIfc;
    endinterface

endmodule

// Convert 2 DataStream input to 1 PcieAxiStream output
// - The axistream is in straddle mode which means tKeep and tLast are ignored
// - The core use isSop and isEop to location Tlp and allow 2 Tlp in one beat
// - The input dataStream should be added Descriptor and aligned to DW already
interface ConvertDataStreamsToStraddleAxis;
    interface Vector#(DMA_PATH_NUM, FifoIn#(DataStream))     dataFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoIn#(SideBandByteEn)) byteEnFifoIn;
    interface FifoOut#(ReqReqAxiStream) axiStreamFifoOut;
endinterface

module mkConvertDataStreamsToStraddleAxis(ConvertDataStreamsToStraddleAxis);
    FIFOF#(SideBandByteEn)   byteEnAFifo <- mkSizedFIFOF(valueOf(BYTEEN_INFIFO_DEPTH));
    FIFOF#(SideBandByteEn)   byteEnBFifo <- mkSizedFIFOF(valueOf(BYTEEN_INFIFO_DEPTH));

    StreamShiftComplex shiftA <- mkStreamShiftComplex(fromInteger(valueOf(STRADDLE_THRESH_BYTE_WIDTH)));
    StreamShiftComplex shiftB <- mkStreamShiftComplex(fromInteger(valueOf(STRADDLE_THRESH_BYTE_WIDTH)));

    FIFOF#(ReqReqAxiStream) axiStreamOutFifo <- mkFIFOF;

    Reg#(Bool) isInStreamAReg <- mkReg(False);
    Reg#(Bool) isInStreamBReg <- mkReg(False);
    Reg#(Bool) isInShiftAReg <- mkReg(False);
    Reg#(Bool) isInShiftBReg <- mkReg(False);
    Reg#(Bool) roundRobinReg <- mkReg(False);

    function Bool hasStraddleSpace(DataStream sdStream);
        return !unpack(sdStream.byteEn[valueOf(STRADDLE_THRESH_BYTE_WIDTH)]);
    endfunction

    function Bool isValidShiftStream(DataStream shiftStream);
        Bool valid = !unpack(shiftStream.byteEn[0]) && unpack(shiftStream.byteEn[valueOf(STRADDLE_THRESH_BYTE_WIDTH)]);
        return valid;
    endfunction

    function PcieRequesterRequestSideBandFrame genRQSideBand(
        PcieTlpCtlIsEopCommon isEop, PcieTlpCtlIsSopCommon isSop, SideBandByteEn byteEnA, SideBandByteEn byteEnB
        );
        let {firstByteEnA, lastByteEnA} = byteEnA;
        let {firstByteEnB, lastByteEnB} = byteEnB;
        let sideBand = PcieRequesterRequestSideBandFrame {
            // Do not use parity check in the core
            parity              : 0,
            // Do not support progress track
            seqNum1             : 0,
            seqNum0             : 0,
            //TODO: Do not support Transaction Processing Hint now, maybe we need TPH for better performance
            tphSteeringTag      : 0,
            tphIndirectTagEn    : 0,
            tphType             : 0,
            tphPresent          : 0,
            // Do not support discontinue
            discontinue         : False,
            // Indicates end of the tlp
            isEop               : isEop,
            // Indicates starts of a new tlp
            isSop               : isSop,
            // Disable when use DWord-aligned Mode
            addrOffset          : 0,
            // Indicates byte enable in the first/last DWord
            lastByteEn          : {pack(lastByteEnB), pack(lastByteEnA)},
            firstByteEn         : {pack(firstByteEnB), pack(firstByteEnA)}
        };
        return sideBand;
    endfunction

    // Pipeline stage 1: get the shift datastream

    // Pipeline Stage 2: get the axiStream data
    rule genStraddlePcie;
        DataStream sendingStream = getEmptyStream;
        DataStream pendingStream = getEmptyStream;
        Bool isSendingA = True;

        // In streamA sending epoch, waiting streamA until isLast
        if (isInStreamAReg) begin
            let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
            sendingStream = isInShiftAReg ? shiftStreamA : oriStreamA;
            shiftA.streamFifoOut.deq;
            isSendingA = True;
            if (shiftB.streamFifoOut.notEmpty && sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                shiftB.streamFifoOut.deq;
                if (isValidShiftStream(shiftStreamB)) begin
                    pendingStream = shiftStreamB;
                end
            end
        end
        // In streamB sending epoch, waiting streamB until isLast
        else if (isInStreamBReg) begin
            let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
            sendingStream = isInShiftBReg ? shiftStreamB : oriStreamB;
            shiftB.streamFifoOut.deq;
            isSendingA = False;
            if (shiftA.streamFifoOut.notEmpty && sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                shiftA.streamFifoOut.deq;
                if (isValidShiftStream(shiftStreamA)) begin
                    pendingStream = shiftStreamA;
                end
            end
        end
        // In Idle, choose one stream to enter new epoch
        else begin
            if (shiftA.streamFifoOut.notEmpty && shiftB.streamFifoOut.notEmpty) begin
                roundRobinReg <= !roundRobinReg;
                if (roundRobinReg) begin
                    let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                    sendingStream = oriStreamA;
                    shiftA.streamFifoOut.deq;
                    isSendingA = True;
                    if (sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                        let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                        shiftB.streamFifoOut.deq;
                        if (isValidShiftStream(shiftStreamB)) begin
                            pendingStream = shiftStreamB;
                        end
                    end
                end
                else begin
                    let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                    sendingStream = oriStreamB;
                    shiftB.streamFifoOut.deq;
                    isSendingA = False;
                    if (sendingStream.isLast && hasStraddleSpace(sendingStream)) begin
                        let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                        shiftA.streamFifoOut.deq;
                        if (isValidShiftStream(shiftStreamA)) begin
                            pendingStream = shiftStreamA;
                        end
                    end
                end
            end
            else if (shiftA.streamFifoOut.notEmpty) begin
                let {oriStreamA, shiftStreamA} = shiftA.streamFifoOut.first;
                sendingStream = oriStreamA;
                shiftA.streamFifoOut.deq;
                isSendingA = True;
                roundRobinReg  <= False;
            end
            else if (shiftB.streamFifoOut.notEmpty) begin 
                let {oriStreamB, shiftStreamB} = shiftB.streamFifoOut.first;
                sendingStream = oriStreamB;
                shiftB.streamFifoOut.deq;
                isSendingA = False;
                roundRobinReg  <= True;
            end
            else begin
                // Do nothing
            end
        end

        if (!isByteEnZero(sendingStream.byteEn)) begin
            // Change the registers and generate PcieAxiStream
            let sideBandByteEn0 = tuple2(0, 0);
            let sideBandByteEn1 = tuple2(0, 0);
            if (isSendingA) begin
                isInStreamAReg <= !sendingStream.isLast;
                isInShiftAReg  <= sendingStream.isLast ? False : isInShiftAReg;
                // Only A sop
                if (sendingStream.isFirst && !pendingStream.isFirst) begin
                    sideBandByteEn0 = byteEnAFifo.first;
                    byteEnAFifo.deq;
                end
                // A sop and B sop
                else if (sendingStream.isFirst && hasStraddleSpace(sendingStream) && pendingStream.isFirst) begin
                    isInStreamBReg <= !pendingStream.isLast;
                    isInShiftBReg  <= !pendingStream.isLast;
                    sideBandByteEn0 = byteEnAFifo.first;
                    byteEnAFifo.deq;
                    sideBandByteEn1 = byteEnBFifo.first;
                    byteEnBFifo.deq;
                end
                // Only B sop
                else if (sendingStream.isLast && hasStraddleSpace(sendingStream) && pendingStream.isFirst) begin
                    isInStreamBReg <= !pendingStream.isLast;
                    isInShiftBReg  <= !pendingStream.isLast;
                    sideBandByteEn0 = byteEnBFifo.first;
                    byteEnBFifo.deq;
                end
            end 
            else begin
                isInStreamBReg <= !sendingStream.isLast;
                isInShiftBReg  <= sendingStream.isLast ? False : isInShiftBReg;
                // Only B sop
                if (sendingStream.isFirst && !pendingStream.isFirst) begin
                    sideBandByteEn0 = byteEnBFifo.first;
                    byteEnBFifo.deq;
                end
                // B sop and A sop
                else if (sendingStream.isFirst && hasStraddleSpace(sendingStream) && pendingStream.isFirst) begin
                    isInStreamAReg <= !pendingStream.isLast;
                    isInShiftAReg  <= !pendingStream.isLast;
                    sideBandByteEn0 = byteEnBFifo.first;
                    byteEnBFifo.deq;
                    sideBandByteEn1 = byteEnAFifo.first;
                    byteEnAFifo.deq;
                end
                else if (sendingStream.isLast && hasStraddleSpace(sendingStream) && pendingStream.isFirst) begin
                    isInStreamAReg <= !pendingStream.isLast;
                    isInShiftAReg  <= !pendingStream.isLast;
                    sideBandByteEn0 = byteEnAFifo.first;
                    byteEnAFifo.deq;
                end
            end

            let isSop = PcieTlpCtlIsSopCommon {
                isSopPtrs  : replicate(0),
                isSop      : 0
            };
            let isEop = PcieTlpCtlIsEopCommon {
                isEopPtrs  : replicate(0),
                isEop      : 0
            };
            
            if (sendingStream.isFirst && pendingStream.isFirst) begin
                isSop.isSop = fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT));
                isSop.isSopPtrs[0] = fromInteger(valueOf(ISSOP_LANE_0));
                isSop.isSopPtrs[1] = fromInteger(valueOf(ISSOP_LANE_32));
            end
            else if (sendingStream.isFirst) begin
                isSop.isSop = fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT));
                isSop.isSopPtrs[0] = fromInteger(valueOf(ISSOP_LANE_0));
            end
            else if (pendingStream.isFirst) begin
                isSop.isSop = fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT));
                isSop.isSopPtrs[0] = fromInteger(valueOf(ISSOP_LANE_32));
            end
            if (pendingStream.isLast && isValidShiftStream(pendingStream)) begin
                isEop.isEop = fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT));
                isEop.isEopPtrs[0] = truncate(convertByteEn2DwordPtr(sendingStream.byteEn));
                isEop.isEopPtrs[1] = truncate(convertByteEn2DwordPtr(pendingStream.byteEn));
            end
            else if (sendingStream.isLast) begin
                isEop.isEop = fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT));
                isEop.isEopPtrs[0] = truncate(convertByteEn2DwordPtr(sendingStream.byteEn));
            end
            
            let sideBand = genRQSideBand(isEop, isSop, sideBandByteEn0, sideBandByteEn1);
            let axiStream = ReqReqAxiStream {
                tData  : sendingStream.data | pendingStream.data,
                tKeep  : -1,
                tLast  : False,
                tUser  : pack(sideBand)
            };
            axiStreamOutFifo.enq(axiStream);
            $display($time, "ns SIM INFO @ mkDataStreamToAxis: tx a AXIS frame, isSop:%d, isSopPtr:%d/%d, isEop:%d, isEopPtr:%d/%d, BE0:%b/%b, BE1:%b/%b, tData:%h", 
                isSop.isSop, isSop.isSopPtrs[0], isSop.isSopPtrs[1], isEop.isEop, isEop.isEopPtrs[0], isEop.isEopPtrs[1], tpl_1(sideBandByteEn0), tpl_2(sideBandByteEn0), tpl_1(sideBandByteEn1), tpl_2(sideBandByteEn1), axiStream.tData);
            if (isEop.isEop >= fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT)) && isEop.isEopPtrs[0] == 0) begin
                $display($time, "ns SIM Warning @ mkDataStreamToAxis: sendingstream byteEn %b", sendingStream.byteEn);
            end
            else if (isEop.isEop == fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT)) && isEop.isEopPtrs[1] == 0) begin
                $display($time, "ns SIM Warning @ mkDataStreamToAxis: pendingstream byteEn %b", pendingStream.byteEn);
            end
        end
    endrule

    Vector#(DMA_PATH_NUM, FifoIn#(DataStream))     dataFifoInIfc   = newVector;
    Vector#(DMA_PATH_NUM, FifoIn#(SideBandByteEn)) byteEnFifoInIfc = newVector;
    dataFifoInIfc[0]   = shiftA.streamFifoIn;
    dataFifoInIfc[1]   = shiftB.streamFifoIn;
    byteEnFifoInIfc[0] = convertFifoToFifoIn(byteEnAFifo);
    byteEnFifoInIfc[1] = convertFifoToFifoIn(byteEnBFifo);
    interface dataFifoIn       = dataFifoInIfc;
    interface byteEnFifoIn     = byteEnFifoInIfc;
    interface axiStreamFifoOut = convertFifoToFifoOut(axiStreamOutFifo);
endmodule

interface ConvertStraddleAxisToDataStream;
    interface FifoIn#(ReqCmplAxiStream) axiStreamFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoOut#(StraddleStream)) dataFifoOut;
endinterface

module mkConvertStraddleAxisToDataStream(ConvertStraddleAxisToDataStream);
    FIFOF#(ReqCmplAxiStream) axiStreamInFifo <- mkFIFOF;
    Vector#(DMA_PATH_NUM, FIFOF#(StraddleStream)) outFifos <- replicateM(mkFIFOF);

    // During TLP varibles
    Vector#(DMA_PATH_NUM, Reg#(Bool)) isInTlpRegs <- replicateM(mkReg(False));
    Vector#(DMA_PATH_NUM, Reg#(Bool)) isCompleted <- replicateM(mkReg(False));
    Vector#(DMA_PATH_NUM, Reg#(SlotToken)) tagReg <- replicateM(mkReg(0));

    function PcieRequesterCompleteDescriptor getDescriptorFromData(PcieTlpCtlIsSopPtr isSopPtr, Data data);
        if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_0))) begin
            return unpack(truncate(data));
        end
        else begin
            return unpack(truncate(data >> valueOf(STRADDLE_THRESH_BIT_WIDTH)));
        end
    endfunction
    
    function Bool isMyValidTlp(DmaPathNo path, PcieRequesterCompleteDescriptor desc);
        Bool valid = (desc.status == fromInteger(valueOf(SUCCESSFUL_CMPL))) && (!desc.isPoisoned);
        Bool pathMatch = (truncate(path) == desc.tag[valueOf(DES_NONEXTENDED_TAG_WIDTH) - 1]);
        return valid && pathMatch;
    endfunction
    
    rule parseAxiStream;
        let axiStream = axiStreamInFifo.first;
        axiStreamInFifo.deq;
        PcieRequesterCompleteSideBandFrame sideBand = unpack(axiStream.tUser);
        let isEop = sideBand.isEop;
        let isSop = sideBand.isSop;
        $display($time, "ns SIM INFO @ mkAxisToDataStream: rx a AXIS frame, isSop:%h, isEop:%d, tData:%h", isSop.isSop, isEop.isEop, axiStream.tData);
        for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
            let sdStream = getEmptyStraddleStream;
            // 2 New TLP
            if (isSop.isSop == fromInteger(valueOf(DOUBLE_TLP_IN_THIS_BEAT))) begin
                let desc0 = getDescriptorFromData(isSop.isSopPtrs[0], axiStream.tData);
                let desc1 = getDescriptorFromData(isSop.isSopPtrs[1], axiStream.tData);
                // Both belong to this path
                if (isMyValidTlp(pathIdx, desc0) && isMyValidTlp(pathIdx, desc1)) begin
                    sdStream.data = axiStream.tData;
                    sdStream.byteEn = sideBand.dataByteEn;
                    sdStream.isDoubleFrame = True;
                    sdStream.isFirst = replicate(True);
                    sdStream.isLast[0] = True;
                    sdStream.isLast[1] = unpack(isEop.isEop[1]);
                    sdStream.tag[0] = truncate(desc0.tag);
                    sdStream.tag[1] = truncate(desc1.tag);
                    sdStream.isCompleted[0] = desc0.isRequestCompleted;
                    sdStream.isCompleted[1] = desc1.isRequestCompleted;
                    outFifos[pathIdx].enq(sdStream);
                    tagReg[pathIdx] <= sdStream.tag[1];
                    isInTlpRegs[pathIdx] <= !sdStream.isLast[1];
                    isCompleted[pathIdx] <= desc1.isRequestCompleted;
                end
                // 1 belongs to this path
                else if (isMyValidTlp(pathIdx, desc1)) begin
                    let isSopPtr = isSop.isSopPtrs[1];
                    sdStream.data = getStraddleData(isSopPtr, axiStream.tData);
                    sdStream.byteEn = getStraddleByteEn(isSopPtr, sideBand.dataByteEn);
                    sdStream.isDoubleFrame = False;
                    sdStream.isFirst[0] = True;
                    sdStream.isLast[0] = unpack(isEop.isEop[1]);
                    sdStream.tag[0] = truncate(desc1.tag);
                    sdStream.isCompleted[0] = desc1.isRequestCompleted;
                    outFifos[pathIdx].enq(sdStream);
                    tagReg[pathIdx] <= sdStream.tag[0];
                    isInTlpRegs[pathIdx] <= !sdStream.isLast[0];
                    isCompleted[pathIdx] <= desc1.isRequestCompleted;
                end
                // 0 belongs to this path
                else if (isMyValidTlp(pathIdx, desc0)) begin
                    let isSopPtr = isSop.isSopPtrs[0];
                    sdStream.data = getStraddleData(isSopPtr, axiStream.tData);
                    sdStream.byteEn = getStraddleByteEn(isSopPtr, sideBand.dataByteEn);
                    sdStream.isDoubleFrame = False;
                    sdStream.isFirst[0] = True;
                    sdStream.isLast[0] = True;
                    sdStream.tag[0] = truncate(desc0.tag);
                    sdStream.isCompleted[0] = desc0.isRequestCompleted;
                    outFifos[pathIdx].enq(sdStream);
                    tagReg[pathIdx] <= sdStream.tag[0];
                    isInTlpRegs[pathIdx] <= False;
                    isCompleted[pathIdx] <= False;
                end
            end
            // Only 1 New Tlp
            else if (isSop.isSop == fromInteger(valueOf(SINGLE_TLP_IN_THIS_BEAT))) begin
                let isSopPtr = isSop.isSopPtrs[0];
                let desc = getDescriptorFromData(isSopPtr, axiStream.tData);
                // The new Tlp starts in Lane0
                if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_0))) begin
                    if (isMyValidTlp(pathIdx, desc)) begin
                        sdStream.data = axiStream.tData;
                        sdStream.byteEn = sideBand.dataByteEn;
                        sdStream.isDoubleFrame = False;
                        sdStream.isFirst[0] = True;
                        sdStream.isLast[0] = unpack(isEop.isEop[0]);
                        sdStream.tag[0] = truncate(desc.tag);
                        sdStream.isCompleted[0] = desc.isRequestCompleted;
                        outFifos[pathIdx].enq(sdStream);
                        tagReg[pathIdx] <= sdStream.tag[0];
                        isInTlpRegs[pathIdx] <= !sdStream.isLast[0];
                        isCompleted[pathIdx] <= desc.isRequestCompleted;
                    end
                end
                // The new Tlp starts in Lane32
                else if (isSopPtr == fromInteger(valueOf(ISSOP_LANE_32))) begin
                    if (isMyValidTlp(pathIdx, desc) && isInTlpRegs[pathIdx]) begin
                        sdStream.data = axiStream.tData;
                        sdStream.byteEn = sideBand.dataByteEn;
                        sdStream.isDoubleFrame = True;
                        sdStream.isFirst[0] = False;
                        sdStream.isLast[0] = True;
                        sdStream.isFirst[1] = True;
                        sdStream.isLast[1] = unpack(isEop.isEop[1]);
                        sdStream.tag[0] = tagReg[pathIdx];
                        sdStream.tag[1] = truncate(desc.tag);
                        sdStream.isCompleted[0] = isCompleted[pathIdx];
                        sdStream.isCompleted[1] = desc.isRequestCompleted;
                        outFifos[pathIdx].enq(sdStream);
                        tagReg[pathIdx] <= sdStream.tag[1];
                        isInTlpRegs[pathIdx] <= !sdStream.isLast[1];
                        isCompleted[pathIdx] <= desc.isRequestCompleted;
                    end
                    else if (isMyValidTlp(pathIdx, desc)) begin
                        sdStream.data = getStraddleData(isSopPtr, axiStream.tData);
                        sdStream.byteEn = getStraddleByteEn(isSopPtr, sideBand.dataByteEn);
                        sdStream.isDoubleFrame = False;
                        sdStream.isFirst[0] = True;
                        sdStream.isLast[0] = unpack(isEop.isEop[1]);
                        sdStream.tag[0] = truncate(desc.tag);
                        sdStream.isCompleted[0] = desc.isRequestCompleted;
                        outFifos[pathIdx].enq(sdStream);
                        tagReg[pathIdx] <= sdStream.tag[0];
                        isInTlpRegs[pathIdx] <= !sdStream.isLast[0];
                        isCompleted[pathIdx] <= desc.isRequestCompleted;
                    end
                    else if (isInTlpRegs[pathIdx]) begin
                        sdStream.data = getStraddleData(0, axiStream.tData);
                        sdStream.byteEn = getStraddleByteEn(0, sideBand.dataByteEn);
                        sdStream.isDoubleFrame = False;
                        sdStream.isFirst[0] = False;
                        sdStream.isLast[0] = True;
                        sdStream.tag[0] = tagReg[pathIdx];
                        sdStream.isCompleted[0] = isCompleted[pathIdx];
                        outFifos[pathIdx].enq(sdStream);
                        tagReg[pathIdx] <= sdStream.tag[0];
                        isInTlpRegs[pathIdx] <= False;
                        isCompleted[pathIdx] <= False;
                    end
                end
            end
            // 0 new Tlp
            else begin
                if (isInTlpRegs[pathIdx]) begin
                    sdStream.data = axiStream.tData;
                    sdStream.byteEn = sideBand.dataByteEn;
                    sdStream.isDoubleFrame = False;
                    sdStream.isFirst[0] = False;
                    sdStream.isLast[0] = unpack(isEop.isEop[0]);
                    sdStream.tag[0] = tagReg[pathIdx];
                    sdStream.isCompleted[0] = isCompleted[pathIdx];
                    outFifos[pathIdx].enq(sdStream);
                    tagReg[pathIdx] <= sdStream.tag[0];
                    isInTlpRegs[pathIdx] <= !sdStream.isLast[0];
                end
            end
        end        
    endrule
    
    Vector#(DMA_PATH_NUM, FifoOut#(StraddleStream)) outIfcs = newVector;
    for (Integer pathIdx = 0; pathIdx < valueOf(DMA_PATH_NUM); pathIdx = pathIdx + 1) begin
        outIfcs[pathIdx] = convertFifoToFifoOut(outFifos[pathIdx]);
    end
    interface axiStreamFifoIn = convertFifoToFifoIn(axiStreamInFifo);
    interface dataFifoOut = outIfcs;
endmodule 




