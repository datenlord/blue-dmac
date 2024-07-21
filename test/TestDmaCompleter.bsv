
import FIFOF::*;
import Vector::*;
import FShow::*;

import SemiFifo::*;
import PrimUtils::*;
import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;
import DmaCompleter::*;

typedef 'hABCD TEST_DATA; 
typedef 'h1234 TEST_ADDR;

typedef 2'b10 TRANSLATED_ADDR_TYPE;

function PcieTlpCtlIsEopCommon getEmptyEop();
    return PcieTlpCtlIsEopCommon {
        isEopPtrs: replicate(0),
        isEop    : 0
    };
endfunction

function PcieTlpCtlIsSopCommon getEmptySop();
    return PcieTlpCtlIsSopCommon {
        isSopPtrs: replicate(0),
        isSop    : 0
    };
endfunction

function CmplReqAxiStream genPseudoHostWriteRequest();
    let descriptor = PcieCompleterRequestDescriptor {
        reserve0      : 0,
        attributes    : 0,
        trafficClass  : 0,
        barAperture   : fromInteger(valueOf(DMA_CSR_ADDR_WIDTH)),
        barId         : 0,
        targetFunction: 0,
        tag           : 0,
        requesterId   : fromInteger(valueOf(TEST_DATA)),
        reserve1      : 0,
        reqType       : fromInteger(valueOf(MEM_WRITE_REQ)),
        dwordCnt      : 1,
        address       : fromInteger(valueOf(TEST_ADDR)),
        addrType      : fromInteger(valueOf(TRANSLATED_ADDR_TYPE))
    };
    Data data = 0;
    data = data | zeroExtend(pack(descriptor));
    Data value = fromInteger(valueOf(TEST_DATA));
    data = data | (value << valueOf(DES_CQ_DESCRIPTOR_WIDTH));
    let sideBand = PcieCompleterRequestSideBandFrame {
        parity          : 0,
        tphSteeringTag  : 0,
        tphType         : 0,
        tphPresent      : 0,
        discontinue     : False,
        isEop           : getEmptyEop,
        isSop           : getEmptySop,
        dataByteEn      : 'hFFF,
        lastByteEn      : 'hF,
        firstByteEn     : 'hF
    };
    return CmplReqAxiStream {
        tData : data,
        tKeep : 'h3FF,
        tLast : True,
        tUser : pack(sideBand)
    };
endfunction

(* doc = "testcase" *) 
module mkTestDmaCompleterRequest(Empty);
    CompleterRequest dut <- mkCompleterRequest;
    Reg#(Bool) isInitReg <- mkReg(False);

    rule testInit if (!isInitReg);
        $display("INFO: Start CompleterRequest test");
        let testAxiStram = genPseudoHostWriteRequest;
        dut.axiStreamFifoIn.enq(testAxiStram);
        isInitReg <= True;
    endrule

    rule testOutput if (isInitReg);
        dut.csrWriteReqFifoOut.deq;
        let wrReq = dut.csrWriteReqFifoOut.first;
        immAssert(
            (wrReq.addr == fromInteger(valueOf(TEST_ADDR)) && wrReq.value == fromInteger(valueOf(TEST_DATA))),
            "wrReq test @ mkTestDmaCompleterRequest",
            fshow(wrReq)
        );
        $display("INFO: Pass CompleterRequest test");
        $finish();
    endrule

endmodule