
import PcieTypes::*;
import PcieAxiStreamTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

interface Requester;
    interface DmaCardToHostWrite        c2hWrite;
    interface DmaCardToHostRead         c2hRead;
    interface RawPcieRequesterRequest   rawRequesterRequest;
    interface RawPcieRequesterComplete  rawRequesterComplete;
endinterface

module mkRequester(Requester);
    FIFOF#(DataStream) c2hWriteDataFifo <- mkFIFOF;
    FIFOF#(DmaRequest) c2hWriteReqFifo  <- mkFIFOF;
    FIFOF#(DataStream) c2hReadDataFifo  <- mkFIFOF;
    FIFOF#(DmaRequest) c2hReadReqFifo   <- mkFIFOF;

    interface c2hWrite;
        interface dataFifoOut = convertFifoToFifoOut(c2hWriteDataFifo);
        interface reqFifoOut  = convertFifoToFifoOut(c2hWriteReqFifo);
    endinterface

    interface c2hRead;
        interface reqFifoOut  = convertFifoToFifoOut(c2hReadReqFifo);
        interface dataFifoIn  = convertFifoToFifoIn(c2hReadDataFifo);
    endinterface

    interface rawRequesterRequest;
    endinterface

    interface rawRequesterComplete;
    endinterface

endmodule
