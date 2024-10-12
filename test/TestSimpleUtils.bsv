import Vector::*;
import RegFile::*;
import GetPut::*;
import SemiFifo::*;
import FIFOF::*;
import BRAM::*;
import Connectable :: *;

import DmaTypes::*;
import StreamUtils::*;
import SimpleModeUtils::*;
import PcieDescriptorTypes::*;
import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieAdapter::*;
import DmaH2CPipe::*;

typedef 2'b10 TRANSLATED_ADDR_TYPE;

module mkTestSimpleCore(Empty);
    DmaSimpleCore core <- mkDmaSimpleCore;
    Reg#(UInt#(32))  testRoundReg <- mkReg(0);

    rule test if (testRoundReg < 50);
        testRoundReg <= testRoundReg + 1;
        case (testRoundReg)
            0: begin
                core.reqFifoIn.enq(CsrRequest {
                    addr   : 1,
                    value  : 'h1234,
                    isWrite: True
                });
            end
            1: begin
                core.reqFifoIn.enq(CsrRequest {
                    addr   : 2,
                    value  : 'h1234,
                    isWrite: True
                });
            end
            2: begin
                core.reqFifoIn.enq(CsrRequest {
                    addr   : 3,
                    value  : 100,
                    isWrite: True
                });
            end
            4: begin
                core.reqFifoIn.enq(CsrRequest {
                    addr   : 0,
                    value  : 1,
                    isWrite: True
                });
            end
            5: begin
                core.reqFifoIn.enq(CsrRequest {
                    addr : 1,
                    value  : 0,
                    isWrite: False
                });
            end
        endcase
        if (core.respFifoOut.notEmpty) begin
            let resp = core.respFifoOut.first;
            core.respFifoOut.deq;
            $display($time, "ns SIM INFO @ mkTestSimpleCore: recv response from dut, address:%h value:%d", resp.addr, resp.value);
        end
        if (core.c2hReqFifoOut[0].notEmpty) begin
            let c2hReq = core.c2hReqFifoOut[0].first;
            core.c2hReqFifoOut[0].deq;
            $display($time, "ns SIM INFO @ mkTestSimpleCore: recv c2hReq from dut, startAddr:%h length:%d isWrite:%d", c2hReq.startAddr, c2hReq.length, c2hReq.isWrite);
        end
    endrule
endmodule

module mkTestSimpleH2CCore(Empty);
    DmaH2CPipe    pipe  <- mkDmaH2CPipe;
    DmaSimpleCore sCore <- mkDmaSimpleCore;

    mkConnection(pipe.csrReqFifoOut, sCore.reqFifoIn);
    mkConnection(pipe.csrRespFifoIn, sCore.respFifoOut);

    Reg#(Bool) testInitReg <- mkReg(False);
    Reg#(Bool) simuDoneReg <- mkReg(False);

    function DataStream genCsrReqTlp(CsrRequest req);
        let pcieDesc = PcieCompleterRequestDescriptor {
            reserve0      : 0,
            attributes    : 0,
            trafficClass  : 0,
            barAperture   : 12,
            barId         : 0,
            targetFunction: 0,
            tag           : 0,
            requesterId   : 'hABCD,
            reserve1      : 0,
            reqType       : req.isWrite ? fromInteger(valueOf(MEM_WRITE_REQ)) :fromInteger(valueOf(MEM_READ_REQ)) ,
            dwordCnt      : 1,
            address       : zeroExtend(req.addr >> 2),
            addrType      : fromInteger(valueOf(TRANSLATED_ADDR_TYPE))
        };
        let tlpData = DataStream {
            data   : zeroExtend(pack(pcieDesc)) | (zeroExtend(req.value) << valueOf(TDiv#(DES_CQ_DESCRIPTOR_WIDTH, BYTE_WIDTH))),
            byteEn : 'hFFF,
            isFirst: True,
            isLast : True
        };
        return tlpData;
    endfunction

    rule testInit if (!testInitReg);
        testInitReg <= True;
    endrule


    rule testRead if (testInitReg);
        let tlpData = genCsrReqTlp(CsrRequest {
            addr  : 1,
            value : 0,
            isWrite : False
        });
        pipe.tlpDataFifoIn.enq(tlpData);
        simuDoneReg <= True;
        $display($time, "ns SIM INFO @ mkTestSimpleH2CCore: send a test read req");
    endrule

    rule testResult if (simuDoneReg);
        let tlp = pipe.tlpDataFifoOut.first;
        pipe.tlpDataFifoOut.deq;
        let desc = truncate(tlp.data);
        DmaCsrValue value = truncate(tlp.data >> valueOf(DES_CQ_DESCRIPTOR_WIDTH));
        $display($time, "ns SIM INFO @ mkTestSimpleH2CCore: received h2c path value:%d, whole cc tlp:%h", value, tlp.data);
        $finish;
    endrule
endmodule



