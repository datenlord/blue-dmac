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

typedef 8 PCIE_RQ_TAG_WIDTH;
typedef Bit#(PCIE_RQ_TAG_WIDTH) PcieRqTag;
typedef PcieTlpCtlSeqNum PcieRqSeqNum;

// Interface to PCIe IP Requester Interface
(*always_ready, always_enabled*)
interface RawPcieRequesterRequest;
    (* prefix = "m_axis_rq_" *) interface RawPcieAxiStreamMaster#(PCIE_REQUESTER_REQUEST_TUSER_WIDTH)  rawAxiStreamMaster;
    (* prefix = "pcie_rq_" *) method Action pcieProgressTrack(
        (* port = "tag_vld0" *)     Bool            tagValid0,
        (* port = "tag_vld1" *)     Bool            tagValid1,
        (* port = "tag0" *)         PcieRqTag       tag0,
        (* port = "tag1" *)         PcieRqTag       tag1,
        (* port = "seq_num_vld0" *) Bool            seqNumValid0,
        (* port = "seq_num_vld1" *) Bool            seqNumValid1,
        (* port = "seq_num0" *)     PcieRqSeqNum    seqNum0,
        (* port = "seq_num1" *)     PcieRqSeqNum    seqNum1
        );
endinterface

(*always_ready, always_enabled*)
interface RawPcieRequesterComplete;
    (* prefix = "s_axis_rc_" *) interface RawPcieAxiStreamSlave#(PCIE_REQUESTER_COMPLETE_TUSER_WIDTH)  rawAxiStreamSlave;
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
    (* prefix = "" *)                    method Action               rdWrDone(
        (* port = "read_write_done" *) Bool cfgMgmtRdWrDone);    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgPm;
    (* result = "aspm_l1_entry_reject" *)       method Bool aspmL1EntryReject;
    (* result = "aspm_tx_l0s_entry_disable" *)  method Bool aspmL0EntryDisable;
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

typedef 16  PCIE_CFG_FUNCTIONS_STATUS_WIDTH;
typedef 504 PCIE_CFG_VIRTUAL_FUNCTIONS_STATUS_WIDTH;
typedef 12  PCIE_CFG_FUNCTIONS_POWER_STATE_WIDTH;
typedef 756 PCIE_CFG_VIRTUAL_FUNC_POWER_STATE_WIDTH;
typedef 2   PCIE_CFG_LINK_POWER_STATE_WIDTH;
typedef Bit#(PCIE_CFG_FUNCTIONS_STATUS_WIDTH)           PcieCfgFunctionStatus;
typedef Bit#(PCIE_CFG_VIRTUAL_FUNCTIONS_STATUS_WIDTH)   PcieCfgVirtualFuncStatus;
typedef Bit#(PCIE_CFG_FUNCTIONS_POWER_STATE_WIDTH)      PcieCfgFuncPowerState;
typedef Bit#(PCIE_CFG_VIRTUAL_FUNC_POWER_STATE_WIDTH)   PcieCfgVFPowerState;
typedef Bit#(PCIE_CFG_LINK_POWER_STATE_WIDTH)           PcieCfgLinkPowerState;

typedef 5 PCIE_CFG_LOCAL_ERROR_WIDTH;
typedef Bit#(PCIE_CFG_LOCAL_ERROR_WIDTH)        PcieCfgLocalError;

typedef 2 PCIE_CFG_RX_PM_STATE_WIDTH;
typedef 2 PCIE_CFG_TX_PM_STATE_WIDTH;
typedef Bit#(PCIE_CFG_RX_PM_STATE_WIDTH)        PcieCfgRxPmState;
typedef Bit#(PCIE_CFG_TX_PM_STATE_WIDTH)        PcieCfgTxPmState;

typedef 6 PCIE_CFG_LTSSM_STATE_WIDTH;
typedef Bit#(PCIE_CFG_LTSSM_STATE_WIDTH)        PcieCfgLtssmState;

typedef 4 PCIE_CFG_RCB_STATUS;
typedef 4 PCIE_CFG_DPA_SUBSTAGE_CHANGE_WIDTH;
typedef 2 PCIE_CFG_OBFF_ENABLE_WIDTH;
typedef Bit#(PCIE_CFG_RCB_STATUS)                   PcieCfgRcbStatus;
typedef Bit#(PCIE_CFG_DPA_SUBSTAGE_CHANGE_WIDTH)    PcieCfgDpaSubstageChange;
typedef Bit#(PCIE_CFG_OBFF_ENABLE_WIDTH)            PcieCfgObffEn;


(*always_ready, always_enabled*)
interface RawPcieCfgStatus;
    method Action getStatus (
        (* port = "phy_link_down" *)        PcieCfgPhyLinkDown       phyLinkDown,
        (* port = "phy_link_status" *)      PcieCfgPhyLinkStatus     phyLinkStatus,
        (* port = "negotiated_width" *)     PcieCfgNegotiatedWidth   negotiatedWidth,
        (* port = "current_speed" *)        PCieCfgCurrentSpeed      currentSpeed,
        (* port = "max_payload" *)          PcieCfgMaxPayloadSize    maxPayloadSize,
        (* port = "max_read_req" *)         PCieCfgMaxReadReqSize    maxReadReqSize,
        (* port = "function_status" *)      PcieCfgFunctionStatus    functionStatus,
        (* port = "vf_status" *)            PcieCfgVirtualFuncStatus virtualFuncStatus,
        (* port = "function_power_state" *) PcieCfgFuncPowerState    functionPowerState,
        (* port = "vf_power_state" *)       PcieCfgVFPowerState      virtualFuncPowerState,
        (* port = "link_power_state" *)     PcieCfgLinkPowerState    linkPowerState,
        (* port = "local_error_out" *)      PcieCfgLocalError        localError,
        (* port = "local_error_valid" *)    Bool                     localErrorValid,
        (* port = "rx_pm_state" *)          PcieCfgRxPmState         rxPmState,
        (* port = "tx_pm_state" *)          PcieCfgTxPmState         txPmState,
        (* port = "ltssm_state" *)          PcieCfgLtssmState        ltssmState,
        (* port = "rcb_status" *)           PcieCfgRcbStatus         rcbStatus,
        (* port = "dpa_substage_change" *)  PcieCfgDpaSubstageChange dpaSubstageChange,
        (* port = "obff_enable" *)          PcieCfgObffEn            obffEnable
    );
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

