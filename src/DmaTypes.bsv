
import SemiFifo :: *;
import PcieTypes :: *;

typedef 512 DMA_DATA_WIDTH;
typedef 64 DMA_HOSTMEM_ADDR_WIDTH;
typedef 32 DMA_CSR_ADDR_WIDTH;
typedef 32 DMA_CSR_DATA_WIDTH;
typedef Bit#(DMA_HOSTMEM_ADDR_WIDTH) DmaMemAddr;
typedef Bit#(DMA_CSR_ADDR_WIDTH) DMACsrAddr;
typedef Bit#(DMA_CSR_DATA_WIDTH) DMACsrValue;

typedef struct {
    Bit#(dataWidth) data;
    Bit#(TDiv#(dataWidth, BYTE_BITS)) byteEn;
    Bool isFirst;
    Bool isLast;
} DataFrame#(numeric type dataWidth) deriving(Bits, Bounded, Eq, FShow);

typedef struct {
    DmaMemAddr startAddr;
    DmaMemAddr length;
} DmaRequestFrame deriving(Bits, Bounded, Eq, FShow);

typedef struct {
    DMACsrAddr address;
    DMACsrValue value;
} DmaCsrFrame deriving(Bits, Bounded, Eq, FShow);

interface DmaController#(numeric type dataWidth);

    interface  FifoIn#(DataFrame#(dataWidth))                         DmaDataC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                                DmaCtrlC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                                DmaCtrlH2CPipeIn;
    interface  FifoOut#(DataFrame#(dataWidth))                        DmaDataH2CPipeOut;

    interface  FifoIn#(DmaCsrFrame)                                   DmaCsrC2HPipeIn;
    interface  FifoOut#(DMACsrAddr)                                   DmaCsrC2HPipeOut;
    interface  FifoOut#(DmaCsrFrame)                                  DmaCsrH2CPipeOut;

    interface  RawPcieRequester                                       PcieRequester;
    interface  RawPcieCompleter                                       PcieCompleter;
    interface  RawPcieConfiguration                                   PcieConfig;

endinterface
