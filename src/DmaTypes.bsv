
import FShow::*;
import SemiFifo::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;

typedef PCIE_AXIS_DATA_WIDTH DATA_WIDTH;
typedef TDiv#(DATA_WIDTH, 2) STRADDLE_THRESH_WIDTH;

typedef 64  DMA_MEM_ADDR_WIDTH;

typedef 32 DMA_CSR_ADDR_WIDTH;
typedef 32 DMA_CSR_DATA_WIDTH;

typedef Bit#(DMA_MEM_ADDR_WIDTH) DmaMemAddr;
typedef Bit#(DMA_CSR_ADDR_WIDTH) DmaCsrAddr;
typedef Bit#(DMA_CSR_DATA_WIDTH) DmaCsrValue;

typedef TLog#(BYTE_WIDTH) BYTE_WIDTH_WIDTH;
typedef 2 BYTE_DWORD_SHIFT_WIDTH;

typedef Bit#(BYTE_WIDTH) Byte;
typedef Bit#(DWORD_WIDTH) DWord;
typedef Bit#(1) ByteParity;

typedef 2 CONCAT_STREAM_NUM;

typedef TDiv#(DATA_WIDTH, BYTE_WIDTH)  BYTE_EN_WIDTH;
typedef TDiv#(DATA_WIDTH, DWORD_WIDTH) DWORD_EN_WIDTH;

typedef Bit#(DATA_WIDTH) Data;
typedef Bit#(BYTE_EN_WIDTH) ByteEn;
typedef Bit#(DWORD_BYTES) DWordByteEn;

typedef Bit#(TAdd#(1, TLog#(DATA_WIDTH)))     DataBitPtr;
typedef Bit#(TAdd#(1, TLog#(BYTE_EN_WIDTH)))  DataBytePtr;
typedef Bit#(TAdd#(1, TLog#(DWORD_EN_WIDTH))) DataDwordPtr;

typedef Bit#(TAdd#(1, TLog#(DWORD_BYTES)))    DWordBytePtr;
typedef Bit#(BYTE_DWORD_SHIFT_WIDTH)          ByteModDWord;

typedef struct {
    DmaMemAddr startAddr;
    DmaMemAddr length;
} DmaRequest deriving(Bits, Bounded, Eq);

typedef enum {
    DMA_RX, 
    DMA_TX
} TRXDirection deriving(Bits, Eq, FShow);

typedef struct {
    Data data;
    ByteEn byteEn;
    Bool isFirst;
    Bool isLast;
} DataStream deriving(Bits, Bounded, Eq);

instance FShow#(DmaRequest);
    function Fmt fshow(DmaRequest request);
        return ($format("<DmaRequest: startAddr=%h, length=%h", request.startAddr, request.length));
    endfunction
endinstance

instance FShow#(DataStream);
    function Fmt fshow(DataStream stream);
        return ($format("<DataStream      \n",
            "     data    = %h\n", stream.data, 
            "     byteEn  = %b\n", stream.byteEn,
            "     isFirst = ", fshow(stream.isFirst), ", isLast = ", fshow(stream.isLast)
        ));
    endfunction
endinstance

interface DmaCardToHostWrite;
    interface FifoIn#(DataStream)       dataFifoIn; 
    interface FifoIn#(DmaRequest)       reqFifoIn;
    method Bool isDone;   // Assert when all data have transmitted to the PCIe
endinterface

interface DmaCardToHostRead;
    interface FifoIn#(DmaRequest)       reqFifoIn;
    interface FifoOut#(DataStream)      dataFifoOut;
endinterface

interface DmaHostToCardWrite;
    interface FifoOut#(DmaCsrValue)     dataFifoOut;
    interface FifoOut#(DmaCsrAddr)      reqFifoOut;
endinterface

interface DmaHostToCardRead;
    interface FifoOut#(DmaCsrAddr)      reqFifoOut;
    interface FifoIn#(DmaCsrValue)      dataFifoIn;    
endinterface
