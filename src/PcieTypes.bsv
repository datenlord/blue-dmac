import Vector::*;

import PcieAxiStreamTypes::*;

typedef 512 PCIE_TLP_BYTES;
typedef TLog#(PCIE_TLP_BYTES) PCIE_TLP_BYTES_WIDTH;

typedef 512 PCIE_TDATA_WIDTH;
typedef 64  PCIE_TDATA_BYTES;
typedef 16  PCIE_TDATA_DWORDS;
// Indicate DWORD valid of tDATA
typedef PCIE_TDATA_DWORDS PCIE_TKEEP_WIDTH;  

// tUser width vary among RR, RC, CR and CC
typedef 183 PCIE_COMPLETER_REQUEST_TUSER_WIDTH;
typedef 81  PCIE_COMPLETER_COMPLETE_TUSER_WIDTH;
typedef 137 PCIE_REQUESTER_REQUEST_TUSER_WIDTH;
typedef 161 PCIE_REQUESTER_COMPLETE_TUSER_WIDTH;


// PcieTlpCtl**: SideBand Signals delivered in tUser defined by PG213
typedef 8  PCIE_TLP_FIRST_BE_WIDTH;
typedef 8  PCIE_TLP_LAST_BE_WIDTH;
typedef Bit#(PCIE_TLP_FIRST_BE_WIDTH)       PcieTlpCtlFirstByteEn;
typedef Bit#(PCIE_TLP_LAST_BE_WIDTH)        PcieTlpCtlLastByteEn;

typedef PCIE_TDATA_BYTES PCIE_TLP_BYTE_EN_WIDTH;
typedef Bit#(PCIE_TLP_BYTE_EN_WIDTH)        PcieTlpCtlByteEn;

typedef 2  PCIE_TLP_ISSOP_WIDTH;
typedef 2  PCIE_TLP_ISSOP_PTR_WIDTH;
typedef Bit#(PCIE_TLP_ISSOP_WIDTH)          PcieTlpCtlIsSop;
typedef Bit#(PCIE_TLP_ISSOP_PTR_WIDTH)      PcieTlpCtlIsSopPtr;

typedef 2  PCIE_TLP_ISEOP_WIDTH;
typedef 4  PCIE_TLP_ISEOP_PTR_WIDTH;
typedef Bit#(PCIE_TLP_ISEOP_WIDTH)          PcieTlpCtlIsEop;
typedef Bit#(PCIE_TLP_ISEOP_PTR_WIDTH)      PcieTlpCtlIsEopPtr;

typedef 2  PCIE_TPH_PRESENT_WIDTH;
typedef 4  PCIE_TPH_TYPE_WIDTH;
typedef 16 PCIE_TPH_STTAG;
typedef 2  PCIE_TPH_INDIRECT_TAGEN_WIDTH;
typedef Bit#(PCIE_TPH_PRESENT_WIDTH)        PcieTlpCtlTphPresent;
typedef Bit#(PCIE_TPH_TYPE_WIDTH)           PcieTlpCtlTphType;
typedef Bit#(PCIE_TPH_STTAG)                PcieTlpCtlTphSteeringTag;
typedef Bit#(PCIE_TPH_INDIRECT_TAGEN_WIDTH) PcieTlpCtlTphIndirectTagEn;

typedef 64 PCIE_TLP_PARITY;              
typedef Bit#(PCIE_TLP_PARITY)               PcieTlpCtlParity;

typedef 4  PCIE_TLP_ADDR_OFFSET_WIDTH;
typedef Bit#(PCIE_TLP_ADDR_OFFSET_WIDTH)    PcieTlpCtlAddrOffset;

typedef 6  PCIE_TLP_SEQ_NUM_WIDTH;
typedef Bit#(PCIE_TLP_SEQ_NUM_WIDTH)        PcieTlpCtlSeqNum;

typedef 4  PCIE_TLP_RC_ISSOP_WIDTH;
typedef Bit#(PCIE_TLP_RC_ISSOP_WIDTH)       PcieTlpCtlIsSopRC;

typedef 4  PCIE_TLP_RC_ISEOP_WIDTH;
typedef Bit#(PCIE_TLP_RC_ISEOP_WIDTH)       PcieTlpCtlIsEopRC;

// Signals the start of a new TLP, 6 bit.
typedef struct {
    Vector#(PCIE_TLP_ISSOP_WIDTH, PcieTlpCtlIsSopPtr) isSopPtrs;
    PcieTlpCtlIsSop                 isSop;
} PcieTlpCtlIsSopCommon deriving(Bits, Bounded, Eq);

// Signals the start of a new TLP, 12 bit.
typedef struct {
    Vector#(PCIE_TLP_RC_ISSOP_WIDTH, PcieTlpCtlIsSopPtr) isSopPtrs;
    PcieTlpCtlIsSopRC               isSop;
} PcieTlpCtlIsSopReqCpl deriving(Bits, Bounded, Eq);

// Indicates a TLP is ending in this beat, 10bit.
typedef struct {
    Vector#(PCIE_TLP_ISEOP_WIDTH, PcieTlpCtlIsEopPtr) isEopPtrs;
    PcieTlpCtlIsEop                 isEop;
} PcieTlpCtlIsEopCommon deriving(Bits, Bounded, Eq);

// Indicates a TLP is ending in this beat, 20bit.
typedef struct {
    Vector#(PCIE_TLP_RC_ISEOP_WIDTH, PcieTlpCtlIsEopPtr) isEopPtrs;
    PcieTlpCtlIsEopRC               isEop;
} PcieTlpCtlIsEopReqCpl deriving(Bits, Bounded, Eq);

// 183bit tUser of PcieCompleterRequeste AXIS-slave
typedef struct {
    PcieTlpCtlParity                parity;
    PcieTlpCtlTphSteeringTag        tphSteeringTag;
    PcieTlpCtlTphType               tphType;
    PcieTlpCtlTphPresent            tphPresent;
    Bool                            discontinue;
    PcieTlpCtlIsEopCommon           isEop;
    PcieTlpCtlIsSopCommon           isSop;
    PcieTlpCtlByteEn                dataByteEn;  
    PcieTlpCtlLastByteEn            lastByteEn;
    PcieTlpCtlFirstByteEn           firstByteEn;
} PcieCompleterRequestSideBandFrame deriving(Bits, Bounded, Eq);

// 81bit tUser of PcieCompleterComplete AXIS-master
typedef struct { 
    PcieTlpCtlParity                parity;
    Bool                            discontinue;
    PcieTlpCtlIsEopCommon           isEop;
    PcieTlpCtlIsSopCommon           isSop;
} PcieCompleterCompleteSideBandFrame deriving(Bits, Bounded, Eq);

// 137bit tUser of PcieRequesterRequeste AXIS-master
typedef struct {
    PcieTlpCtlParity                parity;
    PcieTlpCtlSeqNum                seqNum1;
    PcieTlpCtlSeqNum                seqNum0;
    PcieTlpCtlTphSteeringTag        tphSteeringTag;
    PcieTlpCtlTphIndirectTagEn      tphIndirectTagEn;
    PcieTlpCtlTphType               tphType;
    PcieTlpCtlTphPresent            tphPresent;
    Bool                            discontinue;
    PcieTlpCtlIsEopCommon           isEop;
    PcieTlpCtlIsSopCommon           isSop;
    PcieTlpCtlAddrOffset            addrOffset;
    PcieTlpCtlLastByteEn            lastByteEn;
    PcieTlpCtlFirstByteEn           firstByteEn;
} PcieRequsterRequestSideBandFrame deriving(Bits, Bounded, Eq);

// 161bit tUser of PcieRequesterComplete AXIS-slave
typedef struct {
PcieTlpCtlParity                parity;
Bool                            discontinue;
PcieTlpCtlIsEopReqCpl           isEop;
PcieTlpCtlIsSopReqCpl           isSop;
PcieTlpCtlByteEn                dataByteEn;  
} PcieRequesterCompleteSideBandFrame deriving(Bits, Bounded, Eq);


// PCIe raw interfaces
typedef 2 PCIE_CR_NP_REQ_WIDTH;
typedef 6 PCIE_CR_NP_REQ_COUNT_WIDTH;
typedef Bit#(PCIE_CR_NP_REQ_WIDTH)          PcieNonPostedRequst;
typedef Bit#(PCIE_CR_NP_REQ_COUNT_WIDTH)    PcieNonPostedRequstCount;

// Interface to PCIe IP Completer Interface
(*always_ready, always_enabled*)
interface RawPcieCompleterRequest;
    (* prefix = "s_axis_cq_" *) interface RawPcieAxiStreamSlave#(PCIE_COMPLETER_REQUEST_TUSER_WIDTH) rawAxiStreamSlave;
    (* result = "pcie_cq_np_req" *) method PcieNonPostedRequst nonPostedReqCreditIncrement;
    (* prefix = "" *) method Action nonPostedReqCreditCnt(
        (* port = "pcie_cq_np_req_count" *) PcieNonPostedRequstCount nonPostedpReqCount );
endinterface

(*always_ready, always_enabled*)
interface RawPcieCompleterComplete;
    (* prefix = "m_axis_cc_" *) interface RawPcieAxiStreamMaster#(PCIE_COMPLETER_COMPLETE_TUSER_WIDTH) rawAxiStreamMaster;
endinterface

// Interface to PCIe IP Requester Interface
(*always_ready, always_enabled*)
interface RawPcieRequester;
    (* prefix = "m_axis_rq_" *) interface RawPcieAxiStreamMaster#(PCIE_REQUESTER_REQUEST_TUSER_WIDTH)  request;
    (* prefix = "s_axis_rc_" *) interface RawPcieAxiStreamSlave#(PCIE_REQUESTER_COMPLETE_TUSER_WIDTH)  complete;
endinterface


// Pcie Configuration Interfaces
typedef 10 PCIE_CFG_MGMT_ADDR_WIDTH;
typedef 4  PCIE_CFG_MGMT_BE_WIDTH;
typedef 8  PCIE_CFG_MGMT_FUNC_NUM_WIDTH;
typedef 32 PCIE_CFG_MGMT_DATA_WIDTH;

typedef Bit#(PCIE_CFG_MGMT_ADDR_WIDTH)          PcieCfgMgmtAddr;
typedef Bit#(PCIE_CFG_MGMT_BE_WIDTH)            PcieCfgMgmtByteEn;
typedef Bit#(PCIE_CFG_MGMT_FUNC_NUM_WIDTH)      PcieCfgMgmtFuncNum;
typedef Bit#(PCIE_CFG_MGMT_DATA_WIDTH)          PCieCfgMgmtData;

(*always_ready, always_enabled*)
interface RawPcieCfgMgmt;
    (* result = "addr" *)                method PcieCfgMgmtAddr      addr;
    (* result = "byte_enable" *)         method PcieCfgMgmtByteEn    byteEn;
    (* result = "debug_access" *)        method Bool                 debugAccess;
    (* result = "function_number" *)     method PcieCfgMgmtFuncNum   funcNum;
    (* result = "read" *)                method Bool                 read;
    (* result = "write_data" *)          method PCieCfgMgmtData      writeData;
    (* result = "write" *)               method Bool                 write;
    (* prefix = "" *)                    method Action               readData(
        (* port = "read_data" *)  PCieCfgMgmtData cfgMgmtRdData);
    (* prefix = "" *)                    method Action               writeDone(
        (* port = "write_done" *) Bool cfgMgmtWrDone);    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgPm;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsi;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgInterrupt;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgControl;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgFC;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsgTx;
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsgRx;
    
endinterface

typedef 1 PCIE_CFG_PHY_LINK_DOWN_WIDTH;
typedef 2 PCIE_CFG_PHY_LINK_STATUS_WIDTH;
typedef Bit#(PCIE_CFG_PHY_LINK_DOWN_WIDTH)          PcieCfgPhyLinkDown;
typedef Bit#(PCIE_CFG_PHY_LINK_STATUS_WIDTH)        PcieCfgPhyLinkStatus;

typedef 3 PCIE_CFG_NEGOTIATED_WIDTH_WIDTH;
typedef 3 PCIE_CFG_CURRENT_SPEED_WIDTH;
typedef 2 PCIE_CFG_MAX_PAYLOAD_WIDTH;
typedef 3 PCIE_CFG_MAX_READ_REQ_WIDTH;
typedef Bit#(PCIE_CFG_NEGOTIATED_WIDTH_WIDTH)       PcieCfgNegotiatedWidth;
typedef Bit#(PCIE_CFG_CURRENT_SPEED_WIDTH)          PCieCfgCurrentSpeed;
typedef Bit#(PCIE_CFG_MAX_PAYLOAD_WIDTH)            PcieCfgMaxPayloadSize;
typedef Bit#(PCIE_CFG_MAX_READ_REQ_WIDTH)           PCieCfgMaxReadReqSize;  

typedef 16 PCIE_FUNCTIONS_STATUS_WIDTH;
typedef Bit#(PCIE_FUNCTIONS_STATUS_WIDTH)           PcieCfgFunctionStatus;

(*always_ready, always_enabled*)
interface RawPcieCfgStatus;
    (* result = "phy_link_down" *)      method PcieCfgPhyLinkDown       phyLinkDown;
    (* result = "phy_link_status" *)    method PcieCfgPhyLinkStatus     phyLinkStatus;
    (* result = "negotiated_width" *)   method PcieCfgNegotiatedWidth   negotiatedWidth;
    (* result = "current_speed" *)      method PCieCfgCurrentSpeed      currentSpeed;
    (* result = "max_payload" *)        method PcieCfgMaxPayloadSize    maxPayloadSize;
    (* result = "max_read_req" *)       method PCieCfgMaxReadReqSize    maxReadReqSize;
    (* result = "function_status" *)    method PcieCfgFunctionStatus    functionStatus;
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgTransmitFC;
    
endinterface

interface RawPcieConfiguration;
    (* prefix = "cfg_mgmt_" *)           interface RawPcieCfgMgmt           mgmt;
    (* prefix = "cfg_pm_" *)             interface RawPcieCfgPm             pm;
    (* prefix = "cfg_msi_" *)            interface RawPcieCfgMsi            msi;
    (* prefix = "cfg_interrupt_" *)      interface RawPcieCfgInterrupt      interrupt;
    (* prefix = "cfg_" *)                interface RawPcieCfgControl        control;
    (* prefix = "cfg_fc_" *)             interface RawPcieCfgFC             flowControl;
    (* prefix = "cfg_msg_transmit_" *)   interface RawPcieCfgMsgTx          msgTx;
    (* prefix = "cfg_msg_received_" *)   interface RawPcieCfgMsgRx          msgRx;
    (* prefix = "" *)                    interface RawPcieCfgStatus         status;
    (* prefix = "pcie_tfc_" *)           interface RawPcieCfgTransmitFC     txFlowControl;
endinterface

