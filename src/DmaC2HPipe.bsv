import FIFOF::*;
import GetPut::*;

import SemiFifo::*;
import StreamUtils::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import ReqRequestCore::*;
import DmaTypes::*;

// TODO : change the PCIe Adapter Ifc to TlpData and TlpHeader, 
//        move the module which convert TlpHeader to IP descriptor from dma to adapter
interface DmaC2HPipe;
    // User Logic Ifc
    interface FifoIn#(DataStream)  wrDataFifoIn;
    interface FifoIn#(DmaRequest)  reqFifoIn;
    interface FifoOut#(DataStream) rdDataFifoOut;
    // Pcie Adapter Ifc
    interface FifoOut#(DataStream)     tlpDataFifoOut;
    interface FifoOut#(SideBandByteEn) tlpSideBandFifoOut;
    interface FifoIn#(StraddleStream)  tlpDataFifoIn;
    // TODO: Cfg Ifc
    // interface Put#(DmaConfig)   configuration;
    // interface Client#(DmaCsrValue, DmaCsrValue) statusReg;
endinterface

// Single Path module
module mkDmaC2HPipe(DmaC2HPipe);
    RequesterRequestCore  requestCore  <- mkRequesterRequestCore;
    RequesterCompleteCore completeCore <- mkRequesterCompleteCore;

    FIFOF#(DataStream) dataInFifo   <- mkFIFOF;
    FIFOF#(DmaRequest) reqInFifo    <- mkFIFOF;
    FIFOF#(DataStream) tlpOutFifo   <- mkFIFOF;
    FIFOF#(SideBandByteEn) tlpSideBandFifo <- mkFIFOF;

    rule reqDeMux;
        let req = reqInFifo.first;
        reqInFifo.deq;
        if (req.isWrite) begin
            requestCore.wrReqFifoIn.enq(req);
        end
        else begin
            completeCore.rdReqFifoIn.enq(req);
        end
    endrule

    rule dataPipe;
        let stream = dataInFifo.firts;
        dataInFifo.deq;
        requestCore.dataFifoIn.enq(stream);
    endrule

    rule tlpOutMux;
        
    endrule

    // User Logic Ifc
    interface wrDataFifoIn  = convertFifoToFifoIn(dataInFifo);
    interface reqFifoIn     = convertFifoToFifoIn(reqInFifo);
    interface rdDataFifoOut = completeCore.dataFifoOut;
    // Pcie Adapter Ifc
    interface tlpDataFifoOut      = requestCore.dataFifoOut;
    interface tlpSideBandFifoOut  = requestCore.byteEnFifoOut;
    interface tlpDataFifoIn       = completeCore.dataFifoIn;
    // TODO: Cfg Ifc

endmodule

