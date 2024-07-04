import AxiStreamTypes :: *;

typedef 8 BYTE_BITS
typedef TMul#(4, BYTE_BITS) DWORD_BITS;

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
typedef 64 PCIE_TLP_PARITY              
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
    PcieTlpCtlIsSop                 isSop;
    PcieTlpCtlIsSopPtr              isSopPtr0;
    PcieTlpCtlIsSopPtr              isSopPtr1;
} PcieTlpCtlIsSopCommon deriving(Bits, Bounded, Eq);
// Signals the start of a new TLP, 12 bit.
typedef struct {
    PcieTlpCtlIsSopRC               isSop;
    PcieTlpCtlIsSopPtr              isSopPtr0;
    PcieTlpCtlIsSopPtr              isSopPtr1;
    PcieTlpCtlIsSopPtr              isSopPtr2;
    PcieTlpCtlIsSopPtr              isSopPtr3;
} PcieTlpCtlIsSopReqCpl deriving(Bits, Bounded, Eq);
// Indicates a TLP is ending in this beat, 10bit.
typedef struct {
    PcieTlpCtlIsEop                 isEop;
    PcieTlpCtlIsEopPtr              isEopPtr0;
    PcieTlpCtlIsEopPtr              isEopPtr1;
} PcieTlpCtlIsEopCommon deriving(Bits, Bounded, Eq);
// Indicates a TLP is ending in this beat, 20bit.
typedef struct {
    PcieTlpCtlIsEopRC               isEop;
    PcieTlpCtlIsEopPtr              isEopPtr0;
    PcieTlpCtlIsEopPtr              isEopPtr1;
    PcieTlpCtlIsEopPtr              isEopPtr2;
    PcieTlpCtlIsEopPtr              isEopPtr3;
} PcieTlpCtlIsEopReqCpl deriving(Bits, Bounded, Eq);

// 183bit tUser of PcieCompleterRequeste AXIS-slave
typedef struct {
    PcieTlpCtlFirstByteEn           firstByteEn;
    PcieTlpCtlLastByteEn            lastByteEn;
    PcieTlpCtlByteEn                dataByteEn;  
    PcieTlpCtlIsSopCommon           isSop;
    PcieTlpCtlIsEopCommon           isEop;
    Bool                            discontinue;
    PcieTlpCtlTphPresent            tphPresent;
    PcieTlpCtlTphType               tphType;
    PcieTlpCtlTphSteeringTag        tphSteeringTag;
    PcieTlpCtlParity                parity;
} PcieCompleterRequestSideBandFrame deriving(Bits, Bounded, Eq);
// 81bit tUser of PcieCompleterComplete AXIS-master
typedef struct { 
    PcieTlpCtlIsSopCommon           isSop;
    PcieTlpCtlIsEopCommon           isEop;
    Bool                            discontinue;
    PcieTlpCtlParity                parity;
} PcieCompleterCompleteSideBandFrame deriving(Bits, Bounded, Eq);
// 137bit tUser of PcieRequesterRequeste AXIS-master
typedef struct {
    PcieTlpCtlFirstByteEn           firstByteEn;
    PcieTlpCtlLastByteEn            lastByteEn
    PcieTlpCtlAddrOffset            addrOffset;
    PcieTlpCtlIsSopCommon           isSop;
    PcieTlpCtlIsEopCommon           isEop;
    Bool                            discontinue;
    PcieTlpCtlTphPresent            tphPresent;
    PcieTlpCtlTphType               tphType;
    PcieTlpCtlTphIndirectTagEn      tphIndirectTagEn;
    PcieTlpCtlTphSteeringTag        tphSteeringTag;
    PcieTlpCtlSeqNum                seqNum0;
    PcieTlpCtlSeqNum                seqNum1;
    PcieTlpCtlParity                parity;
} PcieRequsterRequestSideBandFrame deriving(Bits, Bounded, Eq);
// 161 tUser of PcieRequesterComplete AXIS-slave
typedef struct {
    PcieTlpCtlByteEn                dataByteEn;  
    PcieTlpCtlIsSopReqCpl           isSop;
    PcieTlpCtlIsEopReqCpl           isEop;
    Bool                            discontinue;
    PcieTlpCtlParity                parity;
} PcieRequesterCompleteSideBandFrame deriving(Bits, Bounded, Eq);


typedef 2 PCIE_CR_NP_REQ_WIDTH;
typedef 6 PCIE_CR_NP_REQ_COUNT_WIDTH;
typedef Bit#(PCIE_CR_NP_REQ_WIDTH)          PcieNonPostedRequst;
typedef Bit#(PCIE_CR_NP_REQ_COUNT_WIDTH)    PcieNonPostedRequstCount;
// Interface to PCIe IP Completer Interface
(*always_ready, always_enabled*)
interface RawPcieCompleter;
    // TODO: the AxiStream in blue-wrapper has tDataWidth = tKeepWidth * BYTE_BITS, but the PCIe IP has tDataWidth = tKeepWidth * DWORD_BITS
    (* prefix = "s_axis_cq_" *) interface RawAxiStreamSlave#(PCIE_TKEEP_WIDTH, PCIE_COMPLETER_REQUEST_TUSER_WIDTH) Request;
    // (* result = "pcie_cq_np_req" *) method PcieNonPostedRequst nonPostedReqCreditIncrement;
    // (* prefix = "" *) method Action nonPostedReqCreditCnt(
    //     (* port = "pcie_cq_np_req_count" *) PcieNonPostedRequstCount );
    (* prefix = "m_axis_cc_" *) interface RawAxiStreamMaster#(PCIE_TKEEP_WIDTH, PCIE_COMPLETER_COMPLETE_TUSER_WIDTH) Complete;
endinterface

// Interface to PCIe IP Requester Interface
(*always_ready, always_enabled*)
interface RawPcieRequester;
    (* prefix = "m_axis_rq_" *) interface RawAxiStreamMaster#(PCIE_TKEEP_WIDTH, usrWidth)  Request;
    (* prefix = "s_axis_rc_" *) interface RawAxiStreamSlave#(PCIE_TKEEP_WIDTH, usrWidth)   Complete;
endinterface

typedef 10 PCIE_CFG_MGMT_ADDR_WIDTH;
typedef 4  PCIE_CFG_MGMT_BE_WIDTH;
typedef 8  PCIE_CFG_MGMT_FUNC_NUM_WIDTH;
typedef 32 PCIE_CFG_MGMT_DATA_WIDTH;
typedef Bit#(PCIE_CFG_MGMT_ADDR_WIDTH)          PcieCfgMgmtAddr;
typedef Bit#(PCIE_CFG_MGMT_BE_WIDTH)            PcieCfgMgmtByteEn;
typedef Bit#(PCIE_CFG_MGMT_FUNC_NUM_WIDTH)      PcieCfgMgmtFuncNum;
typedef Bit#(PCIE_CFG_MGMT_DATA_WIDTH)          PCieCfgMgmtData;

interface RawPcieConfiguration;
    (* prefix = "cfg_mgmt_" *)               interface RawPcieCfgMgmt;
    (* prefix = "cfg_pm_" *)                 interface RawPcieCfgPm;
    (* prefix = "cfg_msi_" *)                interface RawPcieCfgMsi;
    (* prefix = "cfg_interrupt_" *)          interface RawPcieCfgInterrupt;
    (* prefix = "cfg_" *)                    interface RawPcieCfgControl;
    (* prefix = "cfg_fc_" *)                 interface RawPcieCfgFC;
    (* prefix = "cfg_msg_transmit_" *)       interface RawPcieCfgMsgTx;
    (* prefix = "cfg_msg_received_" *)       interface RawPcieCfgMsgRx;
    (* prefix = "" *)                        interface RawPcieCfgStatus;
    (* prefix = "pcie_tfc_" *)               interface RawPcieCfgTransmitFC;
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMgmt;
    (* result = addr *)                method PcieCfgMgmtAddr      cfgMgmtAddr;
    (* result = byte_enable *)         method PcieCfgMgmtByteEn    cfgMgmtByteEn;
    (* result = debug_access *)        method Bool                 cfgMgmtDebugAccess;
    (* result = function_number *)     method PcieCfgMgmtFuncNum   cfgMgmtFuncNum;
    (* result = read *)                method Bool                 cfgMgmtRead;
    (* result = write_data *)          method PCieCfgMgmtData      cfgMgmtWriteData;
    (* result = write *)               method Bool                 cfgMgmtWrite;
    (* prefix = "" *)                  method Action               cfgMgmtReadData(
        (* port = "read_data" *)  PCieCfgMgmtData cfgMgmtRdData);
    (* prefix = "" *)                  method Action               cfgMgmtWriteDone(
        (* port = "write_done" *) Bool cfgMgmtWrDone);    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgPm#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsi#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgInterrupt#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgControl#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgFC#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsgTx#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMsgRx#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgStatus#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgTransmitFC#();
    
endinterface