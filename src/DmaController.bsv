import FIFOF::*;

import PcieTypes::*;
import DmaTypes::*;  
import DmaCompleter::*;
import DmaRequester::*;

interface DmaController#(numeric type dataWidth);
    // Requester interfaces, where the Card serve as the Master
    interface DmaCardToHostWrite        c2hWrite;
    interface DmaCardToHostRead         c2hRead;

    // Completer interfaces, where the Card serve as the Slave
    interface DmaHostToCardWrite        h2cWrite;
    interface DmaHostToCardRead         h2cRead;

    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    interface RawPcieRequesterRequest   pcieRequesterRequest;
    interface RawPcieRequesterComplete  pcieRequesterComplete;
    interface RawPcieCompleterRequest   pcieCompleterRequest;
    interface RawPcieCompleterComplete  pcieCompleterComplete;
    interface RawPcieConfiguration      pcieConfiguration;
endinterface

module mkDmaController(DmaController);
    DmaCompleter completer = mkDmaCompleter;
    DmaRequester requester = mkDmaRequester;

    interface c2hWrite = requester.c2hWrite;
    interface c2hRead  = requester.c2hRead;

    interface h2cWrite = completer.h2cWrite;
    interface h2cRead  = completer.h2cRead;

    interface pcieRequesterRequest  = requester.rawRequesterRequest;
    interface pcieRequesterComplete = requester.rawRequesterComplete;
    interface pcieCompleterRequest  = completer.rawCompleterRequest;
    interface pcieCompleterComplete = completer.rawCompleterComplete;

endmodule