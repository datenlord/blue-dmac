import Vector::*;
import FIFOF::*;
import SemiFifo::*;

typedef 8 BYTE_WIDTH;
typedef TMul#(4, BYTE_WIDTH) DWORD_WIDTH;

typedef 2 CONCAT_STREAM_NUM;

typedef struct {
    Bit#(dataWidth) data;
    Bit#(TDiv#(dataWidth, BYTE_WIDTH)) byteEn;
    Bool isFirst;
    Bool isLast;
} DataStream#(numeric type dataWidth) deriving(Bits, Bounded, Eq, FShow);

interface StreamConcat#(numeric type dataWidth);
    interface FifoIn#(DataStream#(dataWidth))  inputStreamFirst;
    interface FifoIn#(DataStream#(dataWidth))  inputStreamSecond;
    interface FifoOut#(DataStream#(dataWidth)) outputStream;
endinterface

module mkStreamConcat (StreamConcat#(dataWidth) ifc);

    FIFOF#(DataStream#(dataWidth)) firstInputFifo <- mkFIFOF;
    FIFOF#(DataStream#(dataWidth)) secondInputFifo <- mkFIFOF;
    FIFOF#(DataStream#(dataWidth)) outputFifo <- mkFIFOF;

    Vector#(TMul#(CONCAT_STREAM_NUM, dataWidth), Reg#(Bit#(1))) concatDataReg <- replicateM(mkReg(0));
    Vector#(TDiv#(TMul#(CONCAT_STREAM_NUM, dataWidth), BYTE_WIDTH), Reg#(Bit#(1))) concatByteEnReg <- replicateM(mkReg(0));

    Reg#(DataStream#(dataWidth)) firstStreamReg <- mkRegU;
    Reg#(DataStream#(dataWidth)) secondStreamReg <- mkRegU;


    rule readStreamFirst;
        let stream = firstInputFifo.first;
        // concatDataReg[valueOf(dataWidth)-1:0] <= stream.data;
        // concatByteEnReg[valueOf(dataWidth)-1:0] <= stream.byteEn;
    endrule

    interface inputStreamFirst = convertFifoToFifoIn(firstInputFifo);
    interface inputStreamSecond = convertFifoToFifoIn(secondInputFifo);
    interface outputStream = convertFifoToFifoOut(outputFifo);


endmodule