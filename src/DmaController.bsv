import FIFOF::*;

import PcieTypes::*;
import DmaTypes::*;  

interface DmaController#(numeric type dataWidth);
    // Requester interfaces, where the Card serve as the Master
    interface  FifoIn#(DataStream)                                    c2hDataFifoIn;    // Card writes Host Memory
    interface  FifoIn#(DmaRequest)                               c2hReqFifoIn;     // Card writes Host Memory
    interface  FifoIn#(DmaRequest)                               h2cReqFifoIn;     // Card reads Host Memory
    interface  FifoOut#(DataStream)                                   h2cDataFifoOut;   // Card reads Host Memory

    // Completer interfaces, where the Card serve as the Slave
    interface  FifoIn#(DmaCsrFrame)                                   c2hCsrValFifoIn;  // Host reads Card Registers
    interface  FifoOut#(DMACsrAddr)                                   c2hCsrReqFifoOut; // Host reads Card Registers   
    interface  FifoOut#(DmaCsrFrame)                                  h2cCsrValFifoOut; // Host writes Card Registers

    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    interface  RawPcieRequester                                       pcieRequester;
    interface  RawPcieCompleter                                       pcieCompleter;
    interface  RawPcieConfiguration                                   pcieConfig;
endinterface

module mkDmaController#() (DmaController ifc);
    FIFOF#(DataStream)          c2hDataFifo <- mkFIFOF;
    FIFOF#(DataStream)          h2cDataFifo <- mkFIFOF;
    FIFOF#(DmaRequest)     c2hReqFifo  <- mkFIFOF;
    FIFOF#(DmaRequest)     h2cReqFifo  <- mkFIFOF;

    FIFOF#(DmaCsrFrame)         
endmodule