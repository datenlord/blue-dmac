import Vector::*;
import FIFOF::*;

import SemiFifo::*;
import DmaTypes::*;

typedef 'hAB PSEUDO_DATA;
typedef 8    PSEUDO_DATA_WIDTH;

function Data getPseudoData();
    Data pseudoData = fromInteger(valueOf(PSEUDO_DATA));
    for (Integer idx = 0; idx < valueOf(TDiv#(DATA_WIDTH, PSEUDO_DATA_WIDTH)); idx = idx + 1) begin
        pseudoData = pseudoData | (pseudoData << idx*valueOf(PSEUDO_DATA_WIDTH));
    end
    return pseudoData;
endfunction

function DataStream getPsuedoStream (Bool isFirst, Bool isLast);
    return DataStream{
        data: getPseudoData,
        byteEn: -1,
        isFirst: isFirst,
        isLast: isLast
    };
endfunction

interface TestModule;
    interface Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataFifoIn;
    interface Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataFifoOut;
    interface Vector#(DMA_PATH_NUM, FifoOut#(DmaRequest)) c2hReqFifoOut;

    interface FifoIn#(CsrRequest)   h2cReqFifoIn;
    interface FifoOut#(CsrResponse) h2cRespFifoOut;
endinterface

typedef 250000 ONE_SECOND_COUNTER;
// typedef 250 ONE_SECOND_COUNTER;
typedef 'hfff0 TEST_BASE_ADDR;

typedef Bit#(2) TestState;
typedef 0 IDLE;
typedef 1 WRITING;
typedef 2 READING;
 
module mkTestModule(TestModule);
    Vector#(DMA_PATH_NUM, FIFOF#(DataStream)) dataInFifo  <- replicateM(mkFIFOF);
    Vector#(DMA_PATH_NUM, FIFOF#(DataStream)) dataOutFifo <- replicateM(mkFIFOF);
    Vector#(DMA_PATH_NUM, FIFOF#(DmaRequest)) reqOutFifo  <- replicateM(mkFIFOF);
    FIFOF#(CsrRequest)  csrReqFifo  <- mkFIFOF;
    FIFOF#(CsrResponse) csrRespFifo <- mkFIFOF;

    Reg#(UInt#(32)) cntReg   <- mkReg(0);
    Reg#(UInt#(4))  iterReg  <- mkReg(0);
    Reg#(TestState) stateReg <- mkReg(fromInteger(valueOf(IDLE)));

    Vector#(DMA_PATH_NUM, FifoIn#(DataStream))  c2hDataFifoInIfc  = newVector;
    Vector#(DMA_PATH_NUM, FifoOut#(DataStream)) c2hDataFifoOutIfc = newVector;
    Vector#(DMA_PATH_NUM, FifoOut#(DmaRequest)) c2hReqFifoOutIfc  = newVector;

    for (DmaPathNo pathIdx = 0; pathIdx < fromInteger(valueOf(DMA_PATH_NUM)); pathIdx = pathIdx + 1) begin
        c2hDataFifoInIfc[pathIdx]  = convertFifoToFifoIn(dataInFifo[pathIdx]);
        c2hDataFifoOutIfc[pathIdx] = convertFifoToFifoOut(dataOutFifo[pathIdx]);
        c2hReqFifoOutIfc[pathIdx]   = convertFifoToFifoOut(reqOutFifo[pathIdx]);
    end

    rule counter;
        if (cntReg < fromInteger(valueOf(ONE_SECOND_COUNTER))) begin
            cntReg <= cntReg + 1;
        end
        else begin
            cntReg <= 0;
        end
    endrule

    rule generator;
        case (stateReg)
            fromInteger(valueOf(IDLE)): begin
                if (cntReg == fromInteger(valueOf(ONE_SECOND_COUNTER)-1)) begin
                    stateReg <= fromInteger(valueOf(WRITING));
                    iterReg  <= iterReg + 1;
                    let stream = getPsuedoStream(True, False);
                    let req = DmaRequest {
                        startAddr : (zeroExtend(pack(iterReg))) + fromInteger(valueOf(TEST_BASE_ADDR)),
                        length    : 128,
                        isWrite   : True
                    };
                    dataOutFifo[0].enq(stream);
                    reqOutFifo[0].enq(req);
                end
            end
            fromInteger(valueOf(WRITING)): begin
                stateReg <= fromInteger(valueOf(READING));
                let stream = getPsuedoStream(False, True);
                dataOutFifo[0].enq(stream);
            end
            fromInteger(valueOf(READING)): begin
                stateReg <= fromInteger(valueOf(IDLE));
                let req = DmaRequest {
                    startAddr : (zeroExtend(pack(iterReg))) + fromInteger(valueOf(TEST_BASE_ADDR)),
                    length    : 128,
                    isWrite   : False
                };
                reqOutFifo[0].enq(req);
            end
            default: stateReg <= fromInteger(valueOf(IDLE));
        endcase
    endrule

    interface c2hDataFifoIn  = c2hDataFifoInIfc;
    interface c2hDataFifoOut = c2hDataFifoOutIfc;
    interface c2hReqFifoOut  = c2hReqFifoOutIfc;

    interface h2cReqFifoIn    = convertFifoToFifoIn(csrReqFifo);
    interface h2cRespFifoOut  = convertFifoToFifoOut(csrRespFifo);
endmodule