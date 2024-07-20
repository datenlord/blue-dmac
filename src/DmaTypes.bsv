
import FShow::*;
import SemiFifo::*;
import PcieTypes::*;

typedef 512 DATA_WIDTH;
typedef 64  DMA_MEM_ADDR_WIDTH;

typedef 32 DMA_CSR_ADDR_WIDTH;
typedef 32 DMA_CSR_DATA_WIDTH;

typedef Bit#(DMA_MEM_ADDR_WIDTH) DmaMemAddr;
typedef Bit#(DMA_CSR_ADDR_WIDTH) DMACsrAddr;
typedef Bit#(DMA_CSR_DATA_WIDTH) DMACsrValue;

typedef 8 BYTE_WIDTH;
typedef TLog#(BYTE_WIDTH) BYTE_WIDTH_WIDTH;
typedef TMul#(4, BYTE_WIDTH) DWORD_WIDTH;

typedef 2 CONCAT_STREAM_NUM;

typedef TDiv#(DATA_WIDTH, BYTE_WIDTH) BYTE_EN_WIDTH;
typedef -1 MAX_BYTE_EN;

typedef Bit#(DATA_WIDTH) Data;
typedef Bit#(BYTE_EN_WIDTH) ByteEn;
typedef Bit#(TAdd#(1, TLog#(DATA_WIDTH))) DataBitPtr;
typedef Bit#(TAdd#(1, TLog#(BYTE_EN_WIDTH))) DataBytePtr;

typedef struct {
    DmaMemAddr startAddr;
    DmaMemAddr length;
} DmaRequestFrame deriving(Bits, Bounded, Eq);

typedef struct {
    DMACsrAddr address;
    DMACsrValue value;
} DmaCsrFrame deriving(Bits, Bounded, Eq);

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

instance FShow#(DmaRequestFrame);
    function Fmt fshow(DmaRequestFrame request);
        return ($format("<DmaRequest: startAddr=%h, length=%h", request.startAddr, request.length));
    endfunction
endinstance

instance FShow#(DmaCsrFrame);
    function Fmt fshow(DmaCsrFrame csr);
        return ($format("<CsrFrame: addr=%h, value=%h", csr.address, csr.value));
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
