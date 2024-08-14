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

typedef PcieAxiStream#(PCIE_COMPLETER_REQUEST_TUSER_WIDTH)  CmplReqAxiStream;
typedef PcieAxiStream#(PCIE_COMPLETER_COMPLETE_TUSER_WIDTH) CmplCmplAxiStream;
typedef PcieAxiStream#(PCIE_REQUESTER_REQUEST_TUSER_WIDTH)  ReqReqAxiStream;
typedef PcieAxiStream#(PCIE_REQUESTER_COMPLETE_TUSER_WIDTH) ReqCmplAxiStream;

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

// Only support at most 2 TLP straddle mode on RQ&RC
typedef 2'b00 NO_TLP_IN_THIS_BEAT;
typedef 2'b01 SINGLE_TLP_IN_THIS_BEAT;
typedef 2'b11 DOUBLE_TLP_IN_THIS_BEAT;

typedef 2'b00 ISSOP_LANE_0;
typedef 2'b10 ISSOP_LANE_32;

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
} PcieRequesterRequestSideBandFrame deriving(Bits, Bounded, Eq);

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
(* always_ready, always_enabled *)
interface RawPcieCompleterRequest;
    (* prefix = "s_axis_cq" *) interface RawPcieAxiStreamSlave#(PCIE_COMPLETER_REQUEST_TUSER_WIDTH) rawAxiStreamSlave;
    (* result = "pcie_cq_np_req" *) method PcieNonPostedRequst nonPostedReqCreditIncrement;
    (* prefix = "" *) method Action nonPostedReqCreditCnt(
        (* port = "pcie_cq_np_req_count" *) PcieNonPostedRequstCount nonPostedpReqCount );
endinterface

(* always_ready, always_enabled *)
interface RawPcieCompleterComplete;
    (* prefix = "m_axis_cc" *) interface RawPcieAxiStreamMaster#(PCIE_COMPLETER_COMPLETE_TUSER_WIDTH) rawAxiStreamMaster;
endinterface

typedef 8 PCIE_RQ_TAG_WIDTH;
typedef Bit#(PCIE_RQ_TAG_WIDTH) PcieRqTag;
typedef PcieTlpCtlSeqNum PcieRqSeqNum;

// Interface to PCIe IP Requester Interface
(* always_ready, always_enabled *)
interface RawPcieRequesterRequest;
    (* prefix = "m_axis_rq" *) interface RawPcieAxiStreamMaster#(PCIE_REQUESTER_REQUEST_TUSER_WIDTH)  rawAxiStreamMaster;
    (* prefix = "pcie_rq" *) method Action pcieProgressTrack(
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

(* always_ready, always_enabled *)
interface RawPcieRequesterComplete;
    (* prefix = "s_axis_rc" *) interface RawPcieAxiStreamSlave#(PCIE_REQUESTER_COMPLETE_TUSER_WIDTH)  rawAxiStreamSlave;
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

(* always_ready, always_enabled *)
interface RawPcieCfgMgmt;
    (* result = "addr" *)                method PcieCfgMgmtAddr      addr;
    (* result = "byte_enable" *)         method PcieCfgMgmtByteEn    byteEn;
    (* result = "debug_access" *)        method Bool                 debugAccess;
    (* result = "function_number" *)     method PcieCfgMgmtFuncNum   funcNum;
    (* result = "read" *)                method Bool                 read;
    (* result = "write_data" *)          method PCieCfgMgmtData      writeData;
    (* result = "write" *)               method Bool                 write;
    (* prefix = "" *)                    method Action               getResp(
        (* port = "read_data" *)            PCieCfgMgmtData cfgMgmtRdData,
        (* port = "read_write_done" *)      Bool cfgMgmtRdWrDone);
endinterface

(* always_ready, always_enabled *)
interface RawPcieCfgPm;
    (* result = "aspm_l1_entry_reject" *)       method Bool aspmL1EntryReject;
    (* result = "aspm_tx_l0s_entry_disable" *)  method Bool aspmL0EntryDisable;
endinterface

typedef 4  PCIE_CFG_MSI_ENABLE_WIDTH;
typedef 32 PCIE_CFG_MSI_INT_WIDTH;
typedef 8  PCIE_CFG_MSI_FUNC_NUM_WIDTH;
typedef 12 PCIE_CFG_MSI_MMENABLE_WIDTH;
typedef 32 PCIE_CFG_MSI_PENDING_STATUS_WIDTH;
typedef 2  PCIE_CFG_MSI_PENDING_STATUS_FUNC_NUM_WIDTH;
typedef 2  PCIE_CFG_MSI_SELECT_WIDTH;
typedef 32 PCIE_CFG_MSI_DATA;
typedef 3  PCIE_CFG_MSI_ATTR;
typedef 2  PCIE_CFG_MSI_TPH_TYPE_WIDTH;
typedef 8  PCIE_CFG_MSI_TPH_ST_TAG_WIDTH;

typedef Bit#(PCIE_CFG_MSI_ENABLE_WIDTH)                     PcieCfgMsiEn;
typedef Bit#(PCIE_CFG_MSI_INT_WIDTH)                        PcieCfgMsiInt;
typedef Bit#(PCIE_CFG_MSI_FUNC_NUM_WIDTH)                   PcieCfgMsiFuncNum;
typedef Bit#(PCIE_CFG_MSI_MMENABLE_WIDTH)                   PcieCfgMsiMmEn;
typedef Bit#(PCIE_CFG_MSI_PENDING_STATUS_WIDTH)             PcieCfgMsiPendingStatus;
typedef Bit#(PCIE_CFG_MSI_PENDING_STATUS_FUNC_NUM_WIDTH)    PcieCfgMsiPendingStatusFuncNum;
typedef Bit#(PCIE_CFG_MSI_SELECT_WIDTH)                     PcieCfgMsiSel;
typedef Bit#(PCIE_CFG_MSI_DATA)                             PcieCfgMsiData;
typedef Bit#(PCIE_CFG_MSI_ATTR)                             PcieCfgMsiAttr;
typedef Bit#(PCIE_CFG_MSI_TPH_TYPE_WIDTH)                   PcieCfgMsiTphType;
typedef Bit#(PCIE_CFG_MSI_TPH_ST_TAG_WIDTH)                 PcieCfgMsiTphStTag;

(* always_ready, always_enabled *)
interface RawPcieCfgMsi;
    (* result = "int" *)                         method PcieCfgMsiInt                   msiInt;
    (* result = "function_number" *)             method PcieCfgMsiFuncNum               funcNum;
    (* result = "pending_status" *)              method PcieCfgMsiPendingStatus         pendingStatus;
    (* result = "pending_status_function_num" *) method PcieCfgMsiPendingStatusFuncNum  pendingStatusFuncNum;
    (* result = "pending_status_data_enable" *)  method Bool                            pendingStatusDataEn;
    (* result = "select" *)                      method PcieCfgMsiSel                   sel;
    (* result = "attr" *)                        method PcieCfgMsiAttr                  attr;
    (* result = "tph_present" *)                 method Bool                            tphPresent;
    (* result = "tph_type" *)                    method PcieCfgMsiTphType               tphType;
    (* result = "tph_st_tag" *)                  method PcieCfgMsiTphStTag              tphStTag;
    (* prefix = "" *) method Action getMsiSignals(
        (* port = "enable" *)       Bool            msiEn,
        (* port = "sent" *)         Bool            msiSent,
        (* port = "fail" *)         Bool            msiFail,
        (* port = "mmenable" *)     PcieCfgMsiMmEn  msiMmEn,
        (* port = "mask_update" *)  Bool            maskUpdate,
        (* port = "data" *)         PcieCfgMsiData  data
    );
endinterface

typedef 4  PCIE_CFG_INTR_INT_WIDTH;
typedef 4  PCIE_CFG_INTR_PENDING_WIDTH;
typedef Bit#(PCIE_CFG_INTR_INT_WIDTH) PcieCfgIntrInt;
typedef Bit#(PCIE_CFG_INTR_PENDING_WIDTH) PcieCfgIntrPending;

(* always_ready, always_enabled *)
interface RawPcieCfgInterrupt;
    (* result = "int" *)       method PcieCfgIntrInt        intrInt;
    (* result = "pending" *)   method PcieCfgIntrPending    intrPending;
    (* prefix = "" *)          method Action                isIntrSent(
        (* port = "sent" *)    Bool isSent);
endinterface

typedef 64 PCIE_CFG_DSN_WIDTH;
typedef Bit#(PCIE_CFG_DSN_WIDTH) PcieCfgDsn;

typedef 8  PCIE_CFG_DS_BUS_NUM_WIDTH;
typedef 5  PCIE_CFG_DS_DEVICE_NUM_WIDTH;
typedef 3  PCIE_CFG_DS_FUNC_NUM_WIDTH;
typedef 8  PCIE_CFG_DS_PORT_NUM_WIDTH;
typedef Bit#(PCIE_CFG_DS_BUS_NUM_WIDTH)     PcieCfgDsBusNum;
typedef Bit#(PCIE_CFG_DS_DEVICE_NUM_WIDTH)  PcieCfgDsDeviceNum;
typedef Bit#(PCIE_CFG_DS_FUNC_NUM_WIDTH)    PcieCfgDsFuncNum;
typedef Bit#(PCIE_CFG_DS_PORT_NUM_WIDTH)    PcieCfgDsPortNum;

typedef 4   PCIE_CFG_FLR_DONE_WIDTH;
typedef 8   PCIE_CFG_VF_FLR_FUNCNUM_WIDTH;
typedef 4   PCIE_CFG_FLR_INPROC_WIDTH;
typedef 252 PCIE_CFG_VF_FLR_INPROC_WIDTH;
typedef Bit#(PCIE_CFG_FLR_DONE_WIDTH)       PcieCfgFlrDone;
typedef Bit#(PCIE_CFG_VF_FLR_FUNCNUM_WIDTH) PcieCfgVFFlrFuncNum;
typedef Bit#(PCIE_CFG_FLR_DONE_WIDTH)       PcieCfgFlrInProc;
typedef Bit#(PCIE_CFG_VF_FLR_INPROC_WIDTH)  PcieCfgVFFlrInProc;

typedef 8  PCIE_CFG_BUS_NUM_WIDTH;
typedef 16 PCIE_CFG_VEND_ID_WIDTH;
typedef 16 PCIE_CFG_DEV_ID_WIDTH;
typedef 8  PCIE_CFG_REV_ID_WIDTH;
typedef 16 PCIE_CFG_SUBSYS_ID_WIDTH;
typedef Bit#(PCIE_CFG_BUS_NUM_WIDTH)       PcieCfgBusNum;
typedef Bit#(PCIE_CFG_VEND_ID_WIDTH)       PcieCfgVendId;
typedef Bit#(PCIE_CFG_DEV_ID_WIDTH)        PcieCfgDevId;
typedef Bit#(PCIE_CFG_REV_ID_WIDTH)        PcieCfgRevId;
typedef Bit#(PCIE_CFG_SUBSYS_ID_WIDTH)     PcieCfgSubsysId;

(* always_ready, always_enabled *)
interface RawPcieCfgControl;
    (* result = "hot_reset_out" *)          method Bool                 hotResetOut;
    (* prefix = "" *)                       method Action               hotResetIn(
        (* port = "hot_reset_in" *)         Bool hotReset); 
    (* result = "config_space_enable" *)     method Bool                 cfgSpaceEn;
    (* result = "dsn" *)                    method PcieCfgDsn           deviceSerialNum;
    (* result = "ds_bus_number" *)          method PcieCfgDsBusNum      downStreamBusNum;
    (* result = "ds_device_number" *)       method PcieCfgDsDeviceNum   downStreamDeviceNum;
    (* result = "ds_function_number" *)     method PcieCfgDsFuncNum     downStreamFuncNum;
    (* result = "power_state_change_ack" *) method Bool                 powerStateChangeAck;
    (* prefix = "" *)                       method Action               powerStateChangeIntr(
        (* port = "power_state_change_interrupt" *) Bool powerStateChangeIntrrupt);
    (* result = "ds_port_number" *)         method PcieCfgDsPortNum     downStreamPortNum;
    (* result = "err_cor_in" *)             method Bool                 errorCorrectableOut;
    (* prefix = "" *)                       method Action               getError(
        (* port = "err_cor_out" *)          Bool errorCorrectable,
        (* port = "err_fatal_out" *)        Bool errorFatal,
        (* port = "err_nonfatal_out" *)     Bool errorNonFatal);
    (* result = "err_uncor_in" *)           method Bool                 errorUncorrectable;
    (* result = "flr_done" *)               method PcieCfgFlrDone       funcLevelRstDone;
    (* result = "vf_flr_done" *)            method Bool                 vfFuncLevelRstDone;
    (* result = "vf_flr_func_num" *)        method PcieCfgVFFlrFuncNum  vfFlrFuncNum;
    (* prefix = "" *)                       method Action               getInproc(
        (* port = "flr_in_process" *)       PcieCfgFlrInProc    flrInProcess,
        (* port = "vf_flr_in_process" *)    PcieCfgVFFlrInProc  vfFlrInProcess);
    (* result = "req_pm_transition_l23_ready" *) method Bool            reqPmTransL23Ready;
    (* result = "link_training_enable" *)   method Bool                 linkTrainEn;    
    (* prefix = "" *)                       method Action               busNumber(
        (* port = "bus_number" *)           PcieCfgBusNum busNum);
    (* result = "vend_id" *)                method PcieCfgVendId        vendId;
    (* result = "subsys_vend_id" *)         method PcieCfgVendId        subsysVendId;
    (* result = "dev_id_pf0" *)             method PcieCfgDevId         devIdPf0;
    (* result = "dev_id_pf1" *)             method PcieCfgDevId         devIdPf1;
    (* result = "dev_id_pf2" *)             method PcieCfgDevId         devIdPf2;
    (* result = "dev_id_pf3" *)             method PcieCfgDevId         devIdPf3;
    (* result = "rev_id_pf0" *)             method PcieCfgRevId         revIdPf0;
    (* result = "rev_id_pf1" *)             method PcieCfgRevId         revIdPf1;
    (* result = "rev_id_pf2" *)             method PcieCfgRevId         revIdPf2;
    (* result = "rev_id_pf3" *)             method PcieCfgRevId         revIdPf3;
    (* result = "subsys_id_pf0" *)          method PcieCfgSubsysId      subsysIdPf0;
    (* result = "subsys_id_pf1" *)          method PcieCfgSubsysId      subsysIdPf1;
    (* result = "subsys_id_pf2" *)          method PcieCfgSubsysId      subsysIdPf2;
    (* result = "subsys_id_pf3" *)          method PcieCfgSubsysId      subsysIdPf3;
endinterface

typedef 8  PCIE_CFG_FC_HEADER_WIDTH;
typedef 12 PCIE_CFG_FC_DATA_WIDTH;
typedef 3  PCIE_CFG_FC_SEL_WIDTH;
typedef Bit#(PCIE_CFG_FC_HEADER_WIDTH)  PcieCfgFlowControlHeaderCredit;
typedef Bit#(PCIE_CFG_FC_DATA_WIDTH)    PcieCfgFlowControlDataCredit;
typedef Bit#(PCIE_CFG_FC_SEL_WIDTH)     PcieCfgFlowControlSel;

(* always_ready, always_enabled *)
interface RawPcieCfgFC;
    (* prefix = "" *) method Action flowControl(
        (* port = "ph" *)   PcieCfgFlowControlHeaderCredit postedHeaderCredit,
        (* port = "nph" *)  PcieCfgFlowControlHeaderCredit nonPostedHeaderCredit,
        (* port = "cplh" *) PcieCfgFlowControlHeaderCredit cmplHeaderCredit,
        (* port = "pd" *)   PcieCfgFlowControlDataCredit postedDataCredit,
        (* port = "npd" *)  PcieCfgFlowControlDataCredit nonPostedDataCredit,
        (* port = "cpld" *) PcieCfgFlowControlDataCredit cmplDataCredit
    );
    (* result = "sel" *) method PcieCfgFlowControlSel flowControlSel;
endinterface

typedef 3  PCIE_CFG_MSG_TXTYPE_WIDTH;
typedef 32 PCIE_CFG_MSG_TXDATA_WIDTH;
typedef Bit#(PCIE_CFG_MSG_TXTYPE_WIDTH)    PcieCfgMsgTransType;
typedef Bit#(PCIE_CFG_MSG_TXDATA_WIDTH)    PcieCfgMsgTransData;
(* always_ready, always_enabled *)
interface RawPcieCfgMsgTx;
    (* result = "transmit" *)       method Bool                 msegTransmit;
    (* result = "transmit_type" *)  method PcieCfgMsgTransType  msegTransmitType;
    (* result = "transmit_data" *)  method PcieCfgMsgTransData  msegTransmitData;
    (* prefix = "" *)               method Action               msegTransmitDone(
        (* port = "transmit_done" *) Bool isDone);   
endinterface

typedef 8 PCIE_CFG_MSG_RXDATA_WIDTH;
typedef 5 PCIE_CFG_MSG_RXTYPE_WIDTH;
typedef Bit#(PCIE_CFG_MSG_RXTYPE_WIDTH)    PcieCfgMsgRecvType;
typedef Bit#(PCIE_CFG_MSG_RXDATA_WIDTH)    PcieCfgMsgRecvData;

(* always_ready, always_enabled *)
interface RawPcieCfgMsgRx;
    (* prefix = "" *) method Action receiveMsg(
        (* port = "received" *)      Bool                isMsgReceived,
        (* port = "received_data" *) PcieCfgMsgRecvData  recvData,
        (* port = "received_type" *) PcieCfgMsgRecvType  recvType
    );
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


(* always_ready, always_enabled *)
interface RawPcieCfgStatus;
    (* prefix = "" *) method Action getStatus (
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

typedef 4 PCIE_CFG_TFC_NPH_WIDTH;
typedef 4 PCIE_CFG_TFC_NPD_WIDTH;
typedef Bit#(PCIE_CFG_TFC_NPH_WIDTH)    PcieCfgTfcNphAv;
typedef Bit#(PCIE_CFG_TFC_NPD_WIDTH)    PcieCfgTfcNpdAv;

(* always_ready, always_enabled *)
interface RawPcieCfgTransmitFC;
    (* prefix = "" *) method Action getTransCredit(
        (* port = "nph_av" *) PcieCfgTfcNphAv nphAvailable,
        (* port = "npd_av" *) PcieCfgTfcNpdAv npdAvailable
    );
endinterface

(* always_ready, always_enabled *)
interface RawPcieConfiguration;
    (* prefix = "cfg_mgmt" *)           interface RawPcieCfgMgmt           mgmt;
    (* prefix = "cfg_pm" *)             interface RawPcieCfgPm             pm;
    (* prefix = "cfg_interrupt_msi" *)  interface RawPcieCfgMsi            msi;
    (* prefix = "cfg_interrupt" *)      interface RawPcieCfgInterrupt      interrupt;
    (* prefix = "cfg" *)                interface RawPcieCfgControl        control;
    (* prefix = "cfg_fc" *)             interface RawPcieCfgFC             flowControl;
    (* prefix = "cfg_msg" *)            interface RawPcieCfgMsgTx          msgTx;
    (* prefix = "cfg_msg" *)            interface RawPcieCfgMsgRx          msgRx;
    (* prefix = "cfg" *)                interface RawPcieCfgStatus         status;
    (* prefix = "pcie_tfc" *)           interface RawPcieCfgTransmitFC     txFlowControl;
endinterface

(* always_ready, always_enabled *)
interface RawXilinxPcieIp;
    // Raw PCIe interfaces, connected to the Xilinx PCIe IP
    (* prefix = "" *) interface RawPcieRequesterRequest   requesterRequest;
    (* prefix = "" *) interface RawPcieRequesterComplete  requesterComplete;
    (* prefix = "" *) interface RawPcieCompleterRequest   completerRequest;
    (* prefix = "" *) interface RawPcieCompleterComplete  completerComplete;
    (* prefix = "" *) interface RawPcieConfiguration      configuration;
    (* prefix = "" *) method Action linkUp(
        (* port = "user_lnk_up" *) Bool isLinkUp);
endinterface

(* always_ready, always_enabled *)
interface RawXilinxPcieIpCompleter;
    (* prefix = "" *) interface RawPcieCompleterRequest   completerRequest;
    (* prefix = "" *) interface RawPcieCompleterComplete  completerComplete;
endinterface
