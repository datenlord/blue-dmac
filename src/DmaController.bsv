import PcieTypes::*;
import DmaTypes::*;

interface DmaController#(numeric type dataWidth);

    interface  FifoIn#(DataStream)                                    dataC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                               reqC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                               reqH2CPipeIn;
    interface  FifoOut#(DataStream)                                   dataH2CPipeOut;

    interface  FifoIn#(DmaCsrFrame)                                   csrC2HPipeIn;
    interface  FifoOut#(DMACsrAddr)                                   csrC2HPipeOut;    // read reg in the card from Host
    interface  FifoOut#(DmaCsrFrame)                                  csrH2CPipeOut;

    interface  RawPcieRequester                                       pcieRequester;
    interface  RawPcieCompleter                                       pcieCompleter;
    interface  RawPcieConfiguration                                   pcieConfig;

endinterface

module mkDmaController#() (DmaController ifc);


endmodule