import FIFOF::*;

import PcieTypes::*;
import PcieConfigurator::*;
import DmaTypes::*;  
import DmaCompleter::*;
import DmaRequester::*;

interface DmaController;
    // User Logic Ifc
    interface Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataFifoOut;
    interface Vector#(DMA_PATH_NUM, FifoIn#(DmaRequest))  c2hReqFifoIn;

    interface FifoIn#(DmaCsrValue)  h2cDataFifoIn;
    interface FifoOut#(DmaCsrValue) h2cDataFifoOut;
    interface FifoOut#(DmaCsrAddr)  h2cReqFifoOut;
 
    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    interface RawXilinxPcieIp       rawPcie;
endinterface

// TODO : connect Configurator to other modules
(* synthesize *)
module mkDmaController(DmaController);
    Vector#(DMA_PATH_NUM, DmaC2HPipe) c2hPipes = newVector;
    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        c2hPipes[pathIdx] <- mkDmaC2HPipe(pathIdx);
    end
    DmaH2CPipe h2cPipe <- mkDmaH2cPipe;

    RequesterAxiStreamAdapter reqAdapter  <- mkRequesterAxiStreamAdapter;
    CompleterAxiStreamAdapter cmplAdapter <- mkCompleterAxiStreamAdapter;

    PcieConfigurator configurator <- mkPcieConfigurator;

    Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataInIfc  = newVector;
    Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataOutIfc = newVector;
    Vector#(DMA_PATH_NUM, FifoIn#(DmaRequest))  c2hReqInIfc   = newVector;

    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        rule conncetC2HToAdapter;
            c2hDataInIfc[pathIdx]  = c2hPipes[pathIdx].wrDataFifoIn;
            c2hDataOutIfc[pathIdx] = c2hPipes[pathIdx].rdDataFifoOut;
            c2hReqInIfc[pathIdx]   = c2hPipes[pathIdx].reqFifoIn;
            if (c2hPipes[pathIdx].tlpDataFifoOut.notEmpty) begin
                reqAdapter.dmaDataFifoIn[pathIdx].enq(c2hPipes[pathIdx].tlpDataFifoOut.first);
                c2hPipes[pathIdx].tlpDataFifoOut.deq;
            end
            if (c2hPipes[pathIdx].tlpSideBandFifoOut.notEmpty) begin
                reqAdapter.dmaSideBandFifoIn[pathIdx].enq(c2hPipes[pathIdx].tlpSideBandFifoOut.first);
                c2hPipes[pathIdx].tlpSideBandFifoOut.deq;
            end
            if (reqAdapter.dmaDataFifoOut[pathIdx].notEmpty) begin
                c2hPipes[pathIdx].tlpDataFifoIn.enq(reqAdapter.dmaDataFifoOut[pathIdx].first);
                dmaDataFifoOut[pathIdx].deq;
            end
        endrule
    end

    rule connectH2CToAdapter;
        if (cmplAdapter.dmaDataFifoOut.notEmpty) begin
            h2cPipe.tlpDataFifoIn.enq(cmplAdapter.dmaDataFifoOut.first);
            cmplAdapter.dmaDataFifoOut.deq;
        end
        if (h2cPipe.tlpDataFifoOut.notEmpty) begin
            cmplAdapter.dmaDataFifoIn.enq(h2cPipe.tlpDataFifoOut.first);
            h2cPipe.tlpDataFifoOut.deq;
        end

    endrule

    // User Logic Ifc
    interface c2hDataFifoIn  = c2hDataInIfc;
    interface c2hDataFifoOut = c2hDataOutIfc;
    interface c2hReqFifoIn   = c2hReqFifoIn;
    interface h2cDataFifoIn  = h2cPipe.rdDataFifoIn;
    interface h2cDataFifoOut = h2cPipe.wrDataFifoOut;
    interface h2cReqFifoOut  = h2cPipe.reqFifoOut;

    // Raw PCIe Ifc
    interface RawXilinxPcieIp rawPcie;
        interface requesterRequest  = reqAdapter.rawRequesterRequest;
        interface requesterComplete = reqAdapter.rawRequesterComplete;
        interface completerRequest  = cmplAdapter.rawCompleterRequest;
        interface completerComplete = cmplAdapter.rawCompleterComplete;
        interface configuration     = pcieConfigurator.rawConfiguration;
        method Action linkUp(Bool isLinkUp);
        endmethod
    endinterface
endmodule

