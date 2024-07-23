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

(* synthesize *)
module mkTestDmacCsrWrRdLoop(TestDmacWrRdLoop);

    DmaController dmac <- mkDmaController;

    BRAM2Port#(DmaCsrAddr, DmaCsrValue) ram <- mkBRAM2Server(
        BRAM_Configure {
            memorySize  : valueOf(TEST_BRAM_SIZE),
            loadFormat  : None,
            latency     : 2,
            outFIFODepth: 3,
            allowWriteResponseBypass : False
        }
    );
    
    rule testWriteReq;
        dmac.h2cWrite.dataFifoOut.deq;
        dmac.h2cWrite.reqFifoOut.deq;
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

