import AxiStreamTypes :: *;

// from PG213

typedef 512 PCIE_TDATA_WIDTH
typedef 137 PCIE_TUSER_WIDTH

typedef struct {
    Bit#(8) first_be;
    Bit#(8) last_be;
    Bit#(4) addr_offset;
    Bit#(2) is_sop;
    Bit#(2) is_sop0_ptr;
    Bit#(2) is_sop1_ptr;
    Bit#(2) is_eop;
    Bit#(4) is_eop0_ptr;
    Bit#(4) is_eop1_ptr;
    Bit#(1) discontinue;
    Bit#(2) tph_present;
    Bit#(4) tph_type;
    Bit#(2) tph_indirect_tag_en;
    Bit#(16) tph_st_tag;
    Bit#(6) seq_num0;
    Bit#(6) seq_num1;
    Bit#(64) parity;
} PcieRRSideBandFrame deriving(Bits, Bounded, Eq);

typedef struct {
    Bit#(64) byte_en;
    Bit#(4) is_sop;
    Bit#(2) is_sop0_ptr;
    Bit#(2) is_sop1_ptr;
    Bit#(2) is_sop2_ptr;
} PcieRPSideBandFrame deriving(Bits, Bounded, Eq);

interface RawPcieRequester#(numeric type keepWidth , numeric type usrWidth);
    interface RawAxiStreamMaster#(keepWidth, usrWidth)  Request;
    interface RawAxiStreamSlave#(keepWidth, usrWidth) Complete;
endinterface

interface RawPcieCompleter#(numeric type keepWidth, numeric type usrWidth);
    interface RawAxiStreamSlave#(keepWidth, usrWidth) Request;
    interface RawAxiStreamMaster#(keepWidth, usrWidth) Complete;
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgMgmt#();
    (* result = cfg_mgmt_addr *)                method Bit#(10) cfgMgmtAddr;
    (* result = cfg_mgmt_byte_enable *)         method Bit#(4)  cfgMgmtByteEn;
    (* result = cfg_mgmt_debug_access *)        method Bool     cfgMgmtAddr;
    (* result = cfg_mgmt_function_number *)     method Bit#(8)  cfgMgmFuncNum;
    // (* result = cfg_mgmt_addr *) method Bit#(10) cfgMgmtAddr;
    // (* result = cfg_mgmt_addr *) method Bit#(10) cfgMgmtAddr;
    // (* result = cfg_mgmt_addr *) method Bit#(10) cfgMgmtAddr;
    // (* result = cfg_mgmt_addr *) method Bit#(10) cfgMgmtAddr;
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
interface RawPcieCfgFlowMsgTx#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgFlowMsgRx#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgStatus#();
    
endinterface

(*always_ready, always_enabled*)
interface RawPcieCfgTransmitFC#();
    
endinterface