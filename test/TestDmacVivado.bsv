import FIFOF::*;
import BRAM::*;
import GetPut::*;

import SemiFifo::*;
import PcieTypes::*;
import DmaTypes::*;  
import DmaController::*;

typedef 16384 TEST_BRAM_SIZE;

interface TestDmacWrRdLoop;
    (* prefix = "" *) interface RawXilinxPcieIp rawPcie;
endinterface

(* synthesize, clock_prefix = "user_clk", reset_prefix = "user_reset" *)
module mkTestDmacCsrWrRdLoop((* reset="sys_rst" *) Reset sysRst, TestDmacWrRdLoop ifc);

    DmaController dmac <- mkDmaController;

    BRAM2Port#(DmaCsrAddr, DmaCsrValue) ram <- mkBRAM2Server(
        BRAM_Configure {
            memorySize  : valueOf(TEST_BRAM_SIZE),
            loadFormat  : None,
            latency     : 1,
            outFIFODepth: 3,
            allowWriteResponseBypass : False
        }
    );
    
    rule testWriteReq;
        dmac.h2cWrite.dataFifoOut.deq;
        dmac.h2cWrite.reqFifoOut.deq;
        $display("SIM INFO @ mkTestDmacCsrWrRdLoop: h2cWrite req detect!");
        ram.portA.request.put(
            BRAMRequest {
                write           : True,
                responseOnWrite : False,
                address         : dmac.h2cWrite.reqFifoOut.first,
                datain          : dmac.h2cWrite.dataFifoOut.first
            }
        );
    endrule

    rule testReadReq;
        dmac.h2cRead.reqFifoOut.deq;
        $display("SIM INFO @ mkTestDmacCsrWrRdLoop: h2cRead req detect!");
        ram.portB.request.put(
            BRAMRequest {
                write           : False,
                responseOnWrite : False,
                address         : dmac.h2cRead.reqFifoOut.first,
                datain          : 0
            }
        );
    endrule

    rule testReadResp;
        $display("SIM INFO @ mkTestDmacCsrWrRdLoop: h2cRead resp detect!");
        let value <- ram.portB.response.get;
        dmac.h2cRead.dataFifoIn.enq(value);
    endrule

    interface rawPcie = dmac.rawPcie;
endmodule

// Only use for testing in bsv, do not use for synthesize
interface TestDmacCsrWrRdLoopTb;
    interface RawXilinxPcieIpCompleter rawPcie;
endinterface

module mkTestDmacCsrWrRdLoopTb(TestDmacCsrWrRdLoopTb);

    DmaControllerCompleter dmac <- mkDmaControllerCompleter;

    BRAM2Port#(DmaCsrAddr, DmaCsrValue) ram <- mkBRAM2Server(
        BRAM_Configure {
            memorySize  : valueOf(TEST_BRAM_SIZE),
            loadFormat  : None,
            latency     : 1,
            outFIFODepth: 3,
            allowWriteResponseBypass : False
        }
    );
    
    rule testWriteReq;
        dmac.h2cWrite.dataFifoOut.deq;
        dmac.h2cWrite.reqFifoOut.deq;
        $display("SIM INFO @ mkTestDmacCsrWrRdLoop: h2cWrite req detect!");
        $display("BRAM: PortA write addr %h data %h", dmac.h2cWrite.reqFifoOut.first, dmac.h2cWrite.dataFifoOut.first);
        ram.portA.request.put(
            BRAMRequest {
                write           : True,
                responseOnWrite : False,
                address         : dmac.h2cWrite.reqFifoOut.first,
                datain          : dmac.h2cWrite.dataFifoOut.first
            }
        );
    endrule

    rule testReadReq;
        dmac.h2cRead.reqFifoOut.deq;
        $display("SIM INFO @ mkTestDmacCsrWrRdLoop: h2cRead req detect!");
        $display("BRAM: PortB read addr %h", dmac.h2cRead.reqFifoOut.first);
        ram.portB.request.put(
            BRAMRequest {
                write           : False,
                responseOnWrite : False,
                address         : dmac.h2cRead.reqFifoOut.first,
                datain          : 0
            }
        );
    endrule

    rule testReadResp;
        let value <- ram.portB.response.get;
        dmac.h2cRead.dataFifoIn.enq(value);
    endrule

    interface rawPcie = dmac.rawPcie;
endmodule