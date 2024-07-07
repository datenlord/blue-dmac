
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
    Bit#(TDiv#(dataWidth, BYTE_WIDTH)) byteEn;
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

    interface  FifoIn#(DataFrame#(dataWidth))                         dataC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                               reqC2HPipeIn;
    interface  FifoIn#(DmaRequestFrame)                               reqH2CPipeIn;
    interface  FifoOut#(DataFrame#(dataWidth))                        dataH2CPipeOut;

    interface  FifoIn#(DmaCsrFrame)                                   csrC2HPipeIn;
    interface  FifoOut#(DMACsrAddr)                                   csrC2HPipeOut;    // read reg in the card from Host
    interface  FifoOut#(DmaCsrFrame)                                  csrH2CPipeOut;

    interface  RawPcieRequester                                       pcieRequester;
    interface  RawPcieCompleter                                       pcieCompleter;
    interface  RawPcieConfiguration                                   pcieConfig;

endinterface
