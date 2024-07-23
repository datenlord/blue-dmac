import FIFOF::*;

import PcieTypes::*;
import PcieConfigurator::*;
import DmaTypes::*;  
import DmaCompleter::*;
import DmaRequester::*;

interface DmaController;
    // Requester interfaces, where the Card serve as the Master
    interface DmaCardToHostWrite        c2hWrite;
    interface DmaCardToHostRead         c2hRead;

    // Completer interfaces, where the Card serve as the Slave
    interface DmaHostToCardWrite        h2cWrite;
    interface DmaHostToCardRead         h2cRead;

    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    interface RawXilinxPcieIp           rawPcie;
endinterface

(* synthesize *)
module mkDmaController(DmaController);
    DmaCompleter completer <- mkDmaCompleter;
    DmaRequester requester <- mkDmaRequester;
    PcieConfigurator pcieConfigurator <- mkPcieConfigurator;

    interface c2hWrite = requester.c2hWrite;
    interface c2hRead  = requester.c2hRead;

    interface h2cWrite = completer.h2cWrite;
    interface h2cRead  = completer.h2cRead;

    interface RawXilinxPcieIp rawPcie;
        interface requesterRequest  = requester.rawRequesterRequest;
        interface requesterComplete = requester.rawRequesterComplete;
        interface completerRequest  = completer.rawCompleterRequest;
        interface completerComplete = completer.rawCompleterComplete;
        interface configuration     = pcieConfigurator.rawConfiguration;
        method Action linkUp(Bool isLinkUp);
        endmethod
    endinterface
endmodule
