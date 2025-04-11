import FIFOF :: *;
import GetPut :: *;
import PAClib :: *;

import BusConversion :: *;
import SemiFifo :: *;

typedef 8 BYTE_WIDTH;
typedef 2 WORD_BYTES;
typedef 4 DWORD_BYTES;
typedef TMul#(WORD_BYTES, BYTE_WIDTH)  WORD_WIDTH;
typedef TMul#(DWORD_BYTES, BYTE_WIDTH) DWORD_WIDTH;

typedef 512 PCIE_AXIS_DATA_WIDTH;
typedef TDiv#(PCIE_AXIS_DATA_WIDTH, DWORD_WIDTH) PCIE_AXIS_KEEP_WIDTH;

typedef struct {
    Bit#(PCIE_AXIS_DATA_WIDTH) tData;
    Bit#(PCIE_AXIS_KEEP_WIDTH) tKeep;
    Bool tLast;
    Bit#(usrWidth) tUser;
} PcieAxiStream#(numeric type usrWidth) deriving(Bits, FShow, Eq, Bounded);

(*always_ready, always_enabled*)
interface RawPcieAxiStreamMaster#(numeric type usrWidth);
    (* result = "tvalid" *) method Bool                       tValid;
    (* result = "tdata"  *) method Bit#(PCIE_AXIS_DATA_WIDTH) tData;
    (* result = "tkeep"  *) method Bit#(PCIE_AXIS_KEEP_WIDTH) tKeep;
    (* result = "tlast"  *) method Bool                       tLast;
    (* result = "tuser"  *) method Bit#(usrWidth) tUser;
    (* always_enabled, prefix = "" *) method Action tReady((* port="tready" *) Bool ready);
endinterface

(* always_ready, always_enabled *)
interface RawPcieAxiStreamSlave#(numeric type usrWidth);
   (* prefix = "" *)
   method Action tValid (
        (* port="tvalid" *) Bool                       tValid,
		(* port="tdata"  *) Bit#(PCIE_AXIS_DATA_WIDTH) tData,
		(* port="tkeep"  *) Bit#(PCIE_AXIS_KEEP_WIDTH) tKeep,
		(* port="tlast"  *) Bool                       tLast,
        (* port="tuser"  *) Bit#(usrWidth)             tUser
    );
   (* result="tready" *) method Bool    tReady;
endinterface

module mkFifoOutToRawPcieAxiStreamMaster#(FifoOut#(PcieAxiStream#(usrWidth)) pipe
    )(RawPcieAxiStreamMaster#(usrWidth));
    let rawBus <- mkFifoOutToRawBusMaster(pipe);
    return convertRawBusToRawPcieAxiStreamMaster(rawBus);
endmodule

module mkFifoInToRawPcieAxiStreamSlave#(FifoIn#(PcieAxiStream#(usrWidth)) pipe
    )(RawPcieAxiStreamSlave#(usrWidth));
    let rawBus <- mkFifoInToRawBusSlave(pipe);
    return convertRawBusToRawPcieAxiStreamSlave(rawBus);
endmodule

function RawPcieAxiStreamMaster#(usrWidth) convertRawBusToRawPcieAxiStreamMaster(
    RawBusMaster#(PcieAxiStream#(usrWidth)) rawBus
);
    return (
        interface RawPcieAxiStreamMaster;
            method Bool tValid = rawBus.valid;
            method Bit#(PCIE_AXIS_DATA_WIDTH) tData = rawBus.data.tData;
            method Bit#(PCIE_AXIS_KEEP_WIDTH) tKeep = rawBus.data.tKeep;
            method Bool tLast = rawBus.data.tLast;
            method Bit#(usrWidth) tUser = rawBus.data.tUser;
            method Action tReady(Bool rdy);
                rawBus.ready(rdy);
            endmethod
        endinterface
    );
endfunction

function RawPcieAxiStreamSlave#(usrWidth) convertRawBusToRawPcieAxiStreamSlave(
    RawBusSlave#(PcieAxiStream#(usrWidth)) rawBus
    );
    return (
        interface RawPcieAxiStreamSlave;
            method Bool tReady = rawBus.ready;
            method Action tValid(
                Bool valid, 
                Bit#(PCIE_AXIS_DATA_WIDTH) tData, 
                Bit#(PCIE_AXIS_KEEP_WIDTH) tKeep, 
                Bool tLast, 
                Bit#(usrWidth) tUser
            );
                PcieAxiStream#(usrWidth) axiStream = PcieAxiStream {
                    tData: tData,
                    tKeep: tKeep,
                    tLast: tLast,
                    tUser: tUser
                };
                rawBus.validData(valid, axiStream);
            endmethod
        endinterface
    );
endfunction