
import PcieTypes::*;
import PcieAxiStreamTypes::*;

typedef 256 PCIE_CFG_VF_FLR_INPROC_EXTEND_WIDTH;

interface PcieConfigurator;
    interface RawPcieConfiguration rawConfiguration;
    // TODO: translate raw Ifcs to bluespec style Get Ifcs
    method PcieCfgLtssmState getPcieLtssmState();
endinterface

module mkPcieConfigurator(PcieConfigurator);
    // TODO: the powerStateChangeAck must waitng for completing Done
    Reg#(Bool) powerStateChangeIntrReg <- mkReg(False);

    // Here has a 2-stage pipeline for FLR, according to the Xilinx PCIe Example Design
    // Reg0 means stage0, and Reg1 means stage1
    Reg#(PcieCfgFlrDone)        cfgFlrDoneReg0      <- mkReg(0);
    Reg#(PcieCfgFlrDone)        cfgFlrDoneReg1      <- mkReg(0);
    Reg#(PcieCfgVFFlrFuncNum)   cfgVFFlrFuncNumReg  <- mkReg(0);
    Reg#(PcieCfgVFFlrFuncNum)   cfgVFFlrFuncNumReg1 <- mkReg(0);
    Reg#(Bool)                  cfgVFFlrDoneReg1    <- mkReg(False);
    Reg#(Bit#(PCIE_CFG_VF_FLR_INPROC_EXTEND_WIDTH)) cfgVfFlrInprocReg0 <- mkReg(0);

    rule functionLevelRst;
        cfgVFFlrFuncNumReg  <= cfgVFFlrFuncNumReg + 1;
        cfgFlrDoneReg1      <= cfgFlrDoneReg0;
        cfgVFFlrDoneReg1    <= unpack(cfgVfFlrInprocReg0[cfgVFFlrFuncNumReg]);
        cfgVFFlrFuncNumReg1 <= cfgVFFlrFuncNumReg;
    endrule

    interface RawPcieConfiguration rawConfiguration;

        // not use mgmt
        interface RawPcieCfgMgmt mgmt;
            method PcieCfgMgmtAddr addr;
                return 0;
            endmethod

            method PcieCfgMgmtByteEn byteEn;
                return 0;
            endmethod

            method Bool debugAccess;
                return False;
            endmethod

            method PcieCfgMgmtFuncNum funcNum;
                return 0;
            endmethod

            method Bool read;
                return False;
            endmethod

            method PCieCfgMgmtData writeData;
                return 0;
            endmethod

            method Bool write;
                return False;
            endmethod

            method Action getResp(
                PCieCfgMgmtData cfgMgmtRdData,
                Bool cfgMgmtRdWrDone);
            endmethod
        endinterface

        // assign to 0
        interface RawPcieCfgPm pm;
            method Bool aspmL1EntryReject;
                return False;
            endmethod
            method Bool aspmL0EntryDisable;
                return False;
            endmethod
        endinterface

        // Doesn't support msi now
        interface RawPcieCfgMsi msi;
            method PcieCfgMsiInt  msiInt;
                return 0;
            endmethod

            method PcieCfgMsiFuncNum funcNum;
                return 0;
            endmethod

            method PcieCfgMsiPendingStatus pendingStatus;
                return 0;
            endmethod

            method PcieCfgMsiPendingStatusFuncNum pendingStatusFuncNum;
                return 0;
            endmethod

            method Bool pendingStatusDataEn;
                return False;
            endmethod

            method PcieCfgMsiSel sel;
                return 0;
            endmethod

            method PcieCfgMsiAttr attr;
                return 0;
            endmethod

            method Bool tphPresent;
                return False;
            endmethod

            method PcieCfgMsiTphType tphType;
                return 0;
            endmethod

            method PcieCfgMsiTphStTag tphStTag;
                return 0;
            endmethod

            method Action getMsiSignals(
                PcieCfgMsiEn    msiEn,
                Bool            msiSent,
                Bool            msiFail,
                PcieCfgMsiMmEn  msiMmEn,
                Bool            maskUpdate,
                PcieCfgMsiData  data);
            endmethod
        endinterface

        // Only for Legacy Devices
        interface RawPcieCfgInterrupt interrupt;
            method PcieCfgIntrInt intrInt;
                return 0;
            endmethod

            method PcieCfgIntrPending intrPending;
                return 0;
            endmethod

            method Action isIntrSent(Bool isSent);
            endmethod
        endinterface

        interface RawPcieCfgControl control;
            method Bool hotResetOut;
                return False;
            endmethod

            method Action hotResetIn(Bool hotReset); 
            endmethod

            method Bool cfgSpaceEn;
                return True;
            endmethod

            method PcieCfgDsn deviceSerialNum;
                return 0;
            endmethod

            method PcieCfgDsBusNum downStreamBusNum;
                return 0;
            endmethod

            method PcieCfgDsDeviceNum downStreamDeviceNum;
                return 0;
            endmethod

            method PcieCfgDsFuncNum downStreamFuncNum;
                return 0;
            endmethod

            // TODO: the powerStateChangeAck must waitng for completing Done
            method Bool powerStateChangeAck;
                return powerStateChangeIntrReg;
            endmethod

            method Action powerStateChangeIntr(Bool powerStateChangeIntrrupt);
                powerStateChangeIntrReg <= powerStateChangeIntrrupt;
            endmethod

            method PcieCfgDsPortNum downStreamPortNum;
                return 0;
            endmethod

            method Bool errorCorrectableOut;
                return False;
            endmethod

            method Action getError(
                Bool errorCorrectable,
                Bool errorFatal,
                Bool errorNonFatal);
            endmethod

            method Bool errorUncorrectable;
                return False;
            endmethod

            method PcieCfgFlrDone funcLevelRstDone;
                PcieCfgFlrDone cfgFlrDone = 0;
                cfgFlrDone[0] = (~cfgFlrDoneReg1[0]) & cfgFlrDoneReg0[0];
                cfgFlrDone[1] = (~cfgFlrDoneReg1[1]) & cfgFlrDoneReg0[1];
                return cfgFlrDone;
            endmethod

            method Bool vfFuncLevelRstDone;
                return cfgVFFlrDoneReg1;
            endmethod

            method PcieCfgVFFlrFuncNum vfFlrFuncNum;
                return cfgVFFlrFuncNumReg1;
            endmethod

            method Action getInproc(
                PcieCfgFlrInProc    flrInProcess,
                PcieCfgVFFlrInProc  vfFlrInProcess
            );
                cfgFlrDoneReg0     <= flrInProcess;
                cfgVfFlrInprocReg0 <= zeroExtend(vfFlrInProcess);
            endmethod

            method Bool reqPmTransL23Ready;
                return False;
            endmethod

            method Bool linkTrainEn;   
                return True;
            endmethod 

            method Action busNumber(PcieCfgBusNum busNum);
            endmethod

            method PcieCfgVendId vendId;
                return 0;
            endmethod

            method PcieCfgVendId subsysVendId;
                return 0;
            endmethod

            method PcieCfgDevId devIdPf0;
                return 0;
            endmethod

            method PcieCfgDevId devIdPf1;
                return 0;
            endmethod

            method PcieCfgDevId devIdPf2;
                return 0;
            endmethod

            method PcieCfgDevId devIdPf3;
                return 0;
            endmethod

            method PcieCfgRevId revIdPf0;
                return 0;
            endmethod

            method PcieCfgRevId revIdPf1;
                return 0;
            endmethod

            method PcieCfgRevId revIdPf2;
                return 0;
            endmethod

            method PcieCfgRevId revIdPf3;
                return 0;
            endmethod

            method PcieCfgSubsysId subsysIdPf0;
                return 0;
            endmethod

            method PcieCfgSubsysId subsysIdPf1;
                return 0;
            endmethod

            method PcieCfgSubsysId subsysIdPf2;
                return 0;
            endmethod

            method PcieCfgSubsysId subsysIdPf3;
                return 0;
            endmethod
        endinterface

        interface RawPcieCfgFC flowControl;
            method Action flowControl(
                PcieCfgFlowControlHeaderCredit postedHeaderCredit,
                PcieCfgFlowControlHeaderCredit nonPostedHeaderCredit,
                PcieCfgFlowControlHeaderCredit cmplHeaderCredit,
                PcieCfgFlowControlDataCredit postedDataCredit,
                PcieCfgFlowControlDataCredit nonPostedDataCredit,
                PcieCfgFlowControlDataCredit cmplDataCredit);
            endmethod

            method PcieCfgFlowControlSel flowControlSel;
                return 0;
            endmethod
        endinterface

        // Doesn't support sending Meg
        interface RawPcieCfgMsgTx msgTx;
            method Bool msegTransmit;
                return False;
            endmethod

            method PcieCfgMsgTransType msegTransmitType;
                return 0;
            endmethod

            method PcieCfgMsgTransData msegTransmitData;
                return 0;
            endmethod

            method Action msegTransmitDone(Bool isDone); 
            endmethod
        endinterface

        interface RawPcieCfgMsgRx msgRx;
            method Action receiveMsg(
                Bool                isMsgReceived,
                PcieCfgMsgRecvData  recvData,
                PcieCfgMsgRecvType  recvType
            );
            endmethod
        endinterface

        interface RawPcieCfgStatus status;
            method Action getStatus (
                PcieCfgPhyLinkDown       phyLinkDown,
                PcieCfgPhyLinkStatus     phyLinkStatus,
                PcieCfgNegotiatedWidth   negotiatedWidth,
                PCieCfgCurrentSpeed      currentSpeed,
                PcieCfgMaxPayloadSize    maxPayloadSize,
                PCieCfgMaxReadReqSize    maxReadReqSize,
                PcieCfgFunctionStatus    functionStatus,
                PcieCfgVirtualFuncStatus virtualFuncStatus,
                PcieCfgFuncPowerState    functionPowerState,
                PcieCfgVFPowerState      virtualFuncPowerState,
                PcieCfgLinkPowerState    linkPowerState,
                PcieCfgLocalError        localError,
                Bool                     localErrorValid,
                PcieCfgRxPmState         rxPmState,
                PcieCfgTxPmState         txPmState,
                PcieCfgLtssmState        ltssmState,
                PcieCfgRcbStatus         rcbStatus,
                PcieCfgDpaSubstageChange dpaSubstageChange,
                PcieCfgObffEn            obffEnable);
            endmethod
        endinterface

        interface RawPcieCfgTransmitFC txFlowControl;
            method Action getTransCredit(
                PcieCfgTfcNphAv nphAvailable,
                PcieCfgTfcNpdAv npdAvailable);
            endmethod
        endinterface

    endinterface

    method PcieCfgLtssmState getPcieLtssmState();
        return 0;
    endmethod

endmodule
