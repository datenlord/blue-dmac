import FIFOF::*;
import Vector::*;
import Connectable :: *;

import SemiFifo::*;
import BusConversion::*;
import AxiStreamTypes::*;
import PcieTypes::*;
import PcieConfigurator::*;
import PcieAxiStreamTypes::*;
import PcieAdapter::*;
import DmaTypes::*;  
import DmaUtils::*;
import DmaC2HPipe::*;
import DmaH2CPipe::*;

// For Bsv User

interface DmaController;
    // User Logic Ifc
    interface Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataFifoOut;
    interface Vector#(DMA_PATH_NUM, FifoIn#(DmaRequest))  c2hReqFifoIn;

    interface FifoIn#(DmaCsrValue)  h2cDataFifoIn;
    interface FifoOut#(DmaCsrValue) h2cDataFifoOut;
    interface FifoOut#(DmaRequest)  h2cReqFifoOut;
 
    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    (* prefix = "" *)interface RawXilinxPcieIp       rawPcie;
endinterface

// TODO : connect Configurator to other modules
(* synthesize *)
module mkDmaController(DmaController);
    Vector#(DMA_PATH_NUM, DmaC2HPipe) c2hPipes = newVector;
    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        c2hPipes[pathIdx] <- mkDmaC2HPipe(pathIdx);
    end
    DmaH2CPipe h2cPipe <- mkDmaH2CPipe;

    RequesterAxiStreamAdapter reqAdapter  <- mkRequesterAxiStreamAdapter;
    CompleterAxiStreamAdapter cmplAdapter <- mkCompleterAxiStreamAdapter;

    PcieConfigurator configurator <- mkPcieConfigurator;

    Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataInIfc  = newVector;
    Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataOutIfc = newVector;
    Vector#(DMA_PATH_NUM, FifoIn#(DmaRequest))  c2hReqInIfc   = newVector;

    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        c2hDataInIfc[pathIdx]  = c2hPipes[pathIdx].wrDataFifoIn;
        c2hDataOutIfc[pathIdx] = c2hPipes[pathIdx].rdDataFifoOut;
        c2hReqInIfc[pathIdx]   = c2hPipes[pathIdx].reqFifoIn;
        mkConnection(c2hPipes[pathIdx].tlpDataFifoOut, reqAdapter.dmaDataFifoIn[pathIdx]);
        mkConnection(c2hPipes[pathIdx].tlpSideBandFifoOut, reqAdapter.dmaSideBandFifoIn[pathIdx]);
        mkConnection(reqAdapter.dmaDataFifoOut[pathIdx], c2hPipes[pathIdx].tlpDataFifoIn);
    end

    mkConnection(cmplAdapter.dmaDataFifoOut, h2cPipe.tlpDataFifoIn);
    mkConnection(h2cPipe.tlpDataFifoOut, cmplAdapter.dmaDataFifoIn);

    // User Logic Ifc
    interface c2hDataFifoIn  = c2hDataInIfc;
    interface c2hDataFifoOut = c2hDataOutIfc;
    interface c2hReqFifoIn   = c2hReqInIfc;
    interface h2cDataFifoIn  = h2cPipe.rdDataFifoIn;
    interface h2cDataFifoOut = h2cPipe.wrDataFifoOut;
    interface h2cReqFifoOut  = h2cPipe.reqFifoOut;

    // Raw PCIe Ifc
    interface RawXilinxPcieIp rawPcie;
        interface requesterRequest  = reqAdapter.rawRequesterRequest;
        interface requesterComplete = reqAdapter.rawRequesterComplete;
        interface completerRequest  = cmplAdapter.rawCompleterRequest;
        interface completerComplete = cmplAdapter.rawCompleterComplete;
        interface configuration     = configurator.rawConfiguration;
        method Action linkUp(Bool isLinkUp);
            // let cfgs = configurator.get;
            // c2hpipes[pathIdx].setCfg(cfgs);
        endmethod
    endinterface
endmodule

// For Verilog User

(* always_ready, always_enabled *)
interface RawDmaReqSlave;
    (* prefix = "" *)
    method Action validReq(
        (* port = "valid"    *)     Bool       valid,
        (* port = "start_addr"  *)  DmaMemAddr startAddr,
        (* port = "byte_cnt"  *)    DmaMemAddr length,
        (* port = "is_write"  *)    Bool       isWrite
    );
    (* result = "ready" *) method Bool ready;
endinterface

(* always_ready, always_enabled *)
interface RawDmaCsrReqMaster;
    (* result = "address" *)  method DmaCsrAddr  address;
    (* result = "is_write" *) method Bool        isWrite;
    (* result = "valid" *)    method Bool        valid;
    (* prefix = "" *) method Action ready((* port = "ready" *) Bool rdy);
endinterface

typedef TDiv#(DATA_WIDTH, BYTE_WIDTH) DMA_DATA_KEEP_WIDTH;
typedef 1 DMA_DATA_USER_WIDTH;
typedef RawAxiStreamSlave#(DMA_DATA_KEEP_WIDTH, DMA_DATA_USER_WIDTH)  RawDmaDataSlave;
typedef RawAxiStreamMaster#(DMA_DATA_KEEP_WIDTH, DMA_DATA_USER_WIDTH) RawDmaDataMaster;
typedef AxiStream#(DMA_DATA_KEEP_WIDTH, DMA_DATA_USER_WIDTH) DmaAxiStream;
typedef RawBusMaster#(DmaCsrValue) RawDmaCsrMaster;
typedef RawBusSlave#(DmaCsrValue)  RawDmaCsrSlave;

module mkFifoInToRawDmaDataSlave#(FifoIn#(DataStream) pipe)(RawDmaDataSlave);
    Reg#(Bool) isFirstReg <- mkReg(True);
    let rawBus <- mkFifoInToRawBusSlave(pipe);
    method Bool tReady = rawBus.ready;
    method Action tValid(
        Bool valid, 
        Bit#(DATA_WIDTH) tData, 
        Bit#(DMA_DATA_KEEP_WIDTH) tKeep, 
        Bool tLast, 
        Bit#(DMA_DATA_USER_WIDTH) tUser
    );
        if (valid) begin
            if (tLast) begin
                isFirstReg <= True;
            end
            else if (isFirstReg) begin
                isFirstReg <= False;
            end
        end
        let stream = DataStream {
            data    : tData,
            byteEn  : tKeep,
            isFirst : isFirstReg && valid,
            isLast  : tLast
        };
        rawBus.validData(valid, stream);
    endmethod
endmodule

module mkFifoOutToRawDmaDataMaster#(FifoOut#(DataStream) pipe)(RawDmaDataMaster);
    let rawBus <- mkFifoOutToRawBusMaster(pipe);
    method Bool tValid = rawBus.valid;
    method Bit#(DATA_WIDTH) tData = rawBus.data.data;
    method Bit#(DMA_DATA_KEEP_WIDTH) tKeep = rawBus.data.byteEn;
    method Bool tLast = rawBus.data.isLast;
    method Bit#(DMA_DATA_USER_WIDTH) tUser = 0;
    method Action tReady(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule

module mkFifoInToRawDmaReqSlave#(FifoIn#(DmaRequest) pipe)(RawDmaReqSlave);
    let rawBus <- mkFifoInToRawBusSlave(pipe);
    method Action validReq(
        Bool       valid,
        DmaMemAddr startAddr,
        DmaMemAddr length,
        Bool       isWrite
    );
        let request = DmaRequest {
            startAddr : startAddr,
            length    : length,
            isWrite   : isWrite
        };
        rawBus.validData(valid, request);
    endmethod
    method Bool ready = rawBus.ready;
endmodule

module mkFifoOutToRawCsrReqMaster#(FifoOut#(DmaRequest) pipe)(RawDmaCsrReqMaster);
    let rawBus <- mkFifoOutToRawBusMaster(pipe);
    method DmaCsrAddr  address = truncate(rawBus.data.startAddr);
    method Bool        isWrite = rawBus.data.isWrite;
    method Bool        valid   = rawBus.valid;
    method Action ready(Bool rdy);
        rawBus.ready(rdy);
    endmethod
endmodule

// Raw verilog Wrapper of Dma User Logic Ifc
interface RawDmaController;
    // User Logic Ifc
    (* prefix = "s_axis_c2h_0" *)  interface RawDmaDataSlave  dmaWrData0;
    (* prefix = "s_desc_c2h_0" *)  interface RawDmaReqSlave   dmaDesc0;
    (* prefix = "m_axis_c2h_0" *)  interface RawDmaDataMaster dmaRdData0;

    (* prefix = "s_axis_c2h_1" *)  interface RawDmaDataSlave  dmaWrData1;
    (* prefix = "s_desc_c2h_1" *)  interface RawDmaReqSlave   dmaDesc1;
    (* prefix = "m_axis_c2h_1" *)  interface RawDmaDataMaster dmaRdData1;

    (* prefix = "s_h2c_value" *)   interface RawDmaCsrSlave     dmaRdCsr;
    (* prefix = "m_h2c_value" *)   interface RawDmaCsrReqMaster dmaCsrDesc;
    (* prefix = "m_h2c_desc" *)    interface RawDmaCsrMaster    dmaWrCsr;

    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    (* prefix = "" *)        interface RawXilinxPcieIp       rawPcie;
endinterface

(* synthesize *)
module mkRawDmaController(RawDmaController);
    DmaController dmac <- mkDmaController;

    let dmaWrData0Ifc <- mkFifoInToRawDmaDataSlave(dmac.c2hDataFifoIn[0]);
    let dmaDesc0Ifc   <- mkFifoInToRawDmaReqSlave(dmac.c2hReqFifoIn[0]);
    let dmaRdData0Ifc <- mkFifoOutToRawDmaDataMaster(dmac.c2hDataFifoOut[0]);

    let dmaWrData1Ifc <- mkFifoInToRawDmaDataSlave(dmac.c2hDataFifoIn[1]);
    let dmaDesc1Ifc   <- mkFifoInToRawDmaReqSlave(dmac.c2hReqFifoIn[1]);
    let dmaRdData1Ifc <- mkFifoOutToRawDmaDataMaster(dmac.c2hDataFifoOut[1]);

    let dmaRdCsrIfc   <- mkFifoInToRawBusSlave(dmac.h2cDataFifoIn);
    let dmaWrCsrIfc   <- mkFifoOutToRawBusMaster(dmac.h2cDataFifoOut);
    let dmaCsrDescIfc <- mkFifoOutToRawCsrReqMaster(dmac.h2cReqFifoOut);

    interface dmaWrData0 = dmaWrData0Ifc;
    interface dmaDesc0   = dmaDesc0Ifc;  
    interface dmaRdData0 = dmaRdData0Ifc;
    interface dmaWrData1 = dmaWrData1Ifc;
    interface dmaDesc1   = dmaDesc1Ifc;
    interface dmaRdData1 = dmaRdData1Ifc;
    interface dmaRdCsr   = dmaRdCsrIfc;
    interface dmaCsrDesc = dmaCsrDescIfc;
    interface dmaWrCsr   = dmaWrCsrIfc; 

    interface rawPcie = dmac.rawPcie;
endmodule


