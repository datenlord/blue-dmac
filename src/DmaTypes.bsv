
import FShow::*;
import SemiFifo::*;
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;

typedef PCIE_AXIS_DATA_WIDTH DATA_WIDTH;

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

typedef 4096                                BUS_BOUNDARY;
typedef TAdd#(1, TLog#(BUS_BOUNDARY))       BUS_BOUNDARY_WIDTH;

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

typedef TDiv#(DATA_WIDTH, 2) STRADDLE_THRESH_BIT_WIDTH;
typedef TDiv#(BYTE_EN_WIDTH, 2) STRADDLE_THRESH_BYTE_WIDTH;
typedef TDiv#(DWORD_EN_WIDTH, 2) STRADDLE_THRESH_DWORD_WIDTH;

typedef struct {
    DmaMemAddr startAddr;
    DmaMemAddr length;
    Bool       isWrite;
} DmaRequest deriving(Bits, Bounded, Eq);

typedef struct {
    DmaMemAddr startAddr;
    DmaMemAddr endAddr;
    DmaMemAddr length;
} DmaExtendRequest deriving(Bits, Bounded, Eq);

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

typedef Tuple2#(
    DWordByteEn,
    DWordByteEn
) SideBandByteEn;

instance FShow#(DmaRequest);
    function Fmt fshow(DmaRequest request);
        return ($format("<DmaRequest: startAddr=%h, length=%h, isWrite=%b", request.startAddr, request.length, pack(request.isWrite)));
    endfunction
endinstance

instance FShow#(DataStream);
    function Fmt fshow(DataStream stream);
        return ($format("<DataStream      \n",
            "     data    = %h\n", stream.data, 
            "     byteEn  = %b\n", stream.byteEn,
            "     isFirst = %b", pack(stream.isFirst), ", isLast = %b", pack(stream.isLast)
        ));
    endfunction
endinstance

// Straddle Parameters
typedef struct {
    Data     data;
    ByteEn   byteEn;
    Bool     isDoubleFrame;
    Vector#(PCIE_STRADDLE_NUM, Bool) isFirst;
    Vector#(PCIE_STRADDLE_NUM, Bool) isLast;
    Vector#(PCIE_STRADDLE_NUM, SlotToken)  tag;
    Vector#(PCIE_STRADDLE_NUM, Bool) isCompleted;
} StraddleStream deriving(Bits, Bounded, Eq);

instance FShow#(StraddleStream);
    function Fmt fshow(StraddleStream stream);
        return ($format("<StraddleStream      \n",
            "     data    = %h\n", stream.data, 
            "     byteEn  = %b\n", stream.byteEn,
            "     isDoubleFrame = %b\n", stream.isDoubleFrame,
            "     isFirst = %b", pack(stream.isFirst[0]), ", isLast = %b\n", pack(stream.isLast[0]),
            "     isFirst = %b", pack(stream.isFirst[1]), ", isLast = %b\n", pack(stream.isLast[1])
        ));
    endfunction
endinstance

typedef 2 DMA_PATH_NUM;
typedef 2 PCIE_STRADDLE_NUM;   // set straddle of RC and RQ same in the Xilinx IP GUI

typedef TAdd#(1, TLog#(DMA_PATH_NUM)) DMA_PATH_WIDTH;
typedef Bit#(DMA_PATH_WIDTH) DmaPathNo;

typedef TAdd#(1, TLog#(PCIE_STRADDLE_NUM)) PCIE_STRADDLE_WIDTH;
typedef Bit#(PCIE_STRADDLE_WIDTH) StraddleNo;

// Reorder types
typedef TSub#(DES_NONEXTENDED_TAG_WIDTH, 1) SLOT_TOKEN_WIDTH;
typedef Bit#(SLOT_TOKEN_WIDTH) SlotToken;
typedef 16 SLOT_PER_PATH;
typedef TAdd#(1, TDiv#(BUS_BOUNDARY, BYTE_EN_WIDTH)) MAX_STREAM_NUM_PER_COMPLETION;




