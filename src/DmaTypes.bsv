
import SemiFifo :: *;

typedef 512 DMA_DATA_WIDTH


typedef struct {
    Bit#(dataWidth) data;
    Bit#(TDiv#(dataWidth, 8)) byteEn;
    Bool isFirst;
    Bool isLast;
} DataFrame#(numeric type dataWidth) deriving(Bits, Bounded, Eq, FShow);

typedef struct {
    Bit#(32) address;
    Bit#(32) length;
} CtrlFrame deriving(Bits, Bounded, Eq, FShow);

typedef struct {
    Bit#(32) address;
    Bit#(32) value;
} CsrFrame deriving(Bits, Bounded, Eq, FShow);

interface DmaController#(numeric type dataWidth);

    interface  FifoIn#(DataFrame#(dataWidth))                         DmaDataC2HPipeIn;
    interface  FifoIn#(CtrlFrame)                                     DmaCtrlC2HPipeIn;
    interface  FifoIn#(CtrlFrame)                                     DmaCtrlH2CPipeIn;
    interface  FifoOut#(DataFrame#(dataWidth))                        DmaDataH2CPipeOut;

    interface  FifoIn#(CsrFrame)                                      DmaCsrC2HPipeIn;
    interface  FifoOut#(CsrFrame)                                     DmaCsrC2HPipeOut;
    interface  FifoOut#(CsrFrame)                                     DmaCsrH2CPipeOut;

    interface  RawPcieRequester#(TDiv#(dataWidth, 8), PCIE_USR_WIDTH) PcieRequester;
    interface  RawPcieCompleter#(TDiv#(dataWidth, 8), PCIE_USR_WIDTH) PcieCompleter;
endinterface
