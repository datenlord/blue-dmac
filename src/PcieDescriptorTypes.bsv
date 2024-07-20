
import PcieAxiStreamTypes::*;

typedef 64 RQ_DESCRIPTOR_WIDTH;
typedef TDiv#(TSub#(PCIE_AXIS_DATA_WIDTH, RQ_DESCRIPTOR_WIDTH), DWORD_WIDTH) MAX_DWORD_CNT_OF_FIRST;

typedef Bit#(1) ReserveBit1;

typedef 64 CQ_DESCRIPTOR_WIDTH;
typedef 3  ATTR_WIDTH; 
typedef 3  TC_WIDTH;
typedef 6  BAR_APERTURE_WIDTH;
typedef 3  BAR_ID_WIDTH;
typedef 8  TARGET_FUNCTION_WIDTH;
typedef 8  TAG_WIDTH;
typedef 16 BDF_WIDTH;
typedef 4  REQ_TYPE_WIDTH;
typedef 11 DWORD_COUNT_WIDTH;
typedef 62 ADDR_WIDTH;

typedef Bit#(ATTR_WIDTH)            Attributes;
typedef Bit#(TC_WIDTH)              TrafficClass;
typedef Bit#(BAR_APERTURE_WIDTH)    BarAperture;
typedef Bit#(BAR_ID_WIDTH)          BarId;
typedef Bit#(TARGET_FUNCTION_WIDTH) TargetFunction;
typedef Bit#(TAG_WIDTH)             Tag;
typedef Bit#(BDF_WIDTH)             BusDeviceFunc;
typedef Bit#(REQ_TYPE_WIDTH)        ReqType;
typedef Bit#(DWORD_COUNT_WIDTH)     DwordCount;
typedef Bit#(ADDR_WIDTH)            Address;

// 16bytes Completer Request Descriptor Format for Memory, I/O, and Atomic Options
typedef struct {
    ReserveBit1     reserve0;
    Attributes      attributes;
    TrafficClass    trafficClass;
    BarAperture     barAperture;
    BarId           barId;
    TargetFunction  targetFunction;
    Tag             tag;
    BusDeviceFunc   requesterId;
    ReserveBit1     reserve1;
    ReqType         reqType;
    DwordCount      dwordCnt;
    Address         address;    
} PcieCompleterRequestDescriptor deriving(Bits, Eq, Bounded, FShow);

typedef struct {
    Attributes      attributes;
    TrafficClass    trafficClass;
    Tag             tag;
    BusDeviceFunc   requesterId;
} PcieCompleterRequestNonPostedStore deriving(Bits, Eq, Bounded, FShow);



// Pcie Tlp types of descriptor
typedef 4'b0000 MEM_READ_REQ;
typedef 4'b0001 MEM_WRITE_REQ;
typedef 4'b0010 IO_READ_REQ;
typedef 4'b0011 IO_WRITE_REQ;
typedef 4'b0100 MEM_FETCHADD_REQ;
typedef 4'b0101 MEM_UNCOND_SWAP_REQ;
typedef 4'b0110 MEM_COMP_SWAP_REQ;
typedef 4'b0111 LOCK_READ_REQ; // allowed only in legacy devices
typedef 4'b1100 COMMON_MESG;
typedef 4'b1101 VENDOR_DEF_MESG;
typedef 4'b1110 ATS_MESG;
