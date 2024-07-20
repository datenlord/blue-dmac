import FIFO::*;

import PcieAxiStreamTypes::*;
import PcieTypes::*;
import PcieDescriptorTypes::*;
import DmaTypes::*;

typedef 1 MAX_DWORD_CNT_OF_CSR;
typedef 4'b1111 FIRST_BE_OF_CSR;

typedef DmaCsrFrame CsrWriteReq;
typedef struct {
    DmaCsrAddr rdAddr;
    PcieCompleterRequestNonPostedStore npInfo;
} CsrReadReq;

interface CompleterRequest;
    interface RawPcieCompleterRequest rawCompleterComplete;
    interface FifoOut#(DmaCsrFrame)  csrWriteFifoOut;
    interface FifoOut#(DmaCsrAddr)   csrReadFifoOut;
endinterface

interface CompleterRxEngine;
    interface FifoIn#(PcieAxiStream) axiStreamFifoIn;
    interface FifoOut#(CsrWriteReq)  csrWriteFifoOut;
    interface FifoOut#(CsrReadReq)   csrReadFifoOut;
endinterface


// PcieCompleter does not support straddle mode now
// The completer is designed only for CSR Rd/Wr, and will ignore any len>32bit requests 
module mkCompleterRxEngine;
    FIFOF#(PcieAxiStream)   inFifo  <- mkFIFOF;
    FIFOF#(CsrWriteReq)     wrReqFifo <- mkFIFOF;
    FIFOF#(CsrReadReq)      rdReqFifo <- mkFIFOF;

    Reg#(Bool) isInPacket <- mkReg(False);

    Reg#(Uint#(32)) illegalPcieReqCntReg <- mkReg(0);
    Reg#(BarId) barIdReg <- mkReg(0);

    function DmaCsrAddr getAddrFromCqDescriptor(PcieCompleterRequestDescriptor descriptor);
        
    endfunction

    function PcieCompleterRequestNonPostedStore convertDescriptorToNpStore(PcieCompleterRequestDescriptor descriptor);

    endfunction

    rule parseData;
        inFifo.deq;
        let axiStream = inFifo.first;
        PcieCompleterRequestSideBandFrame sideBand = pack(axiStream.tUser);
        isInPacket <= !unpack(axiStream.isLast);
        if (!isInPacket) begin
            PcieCompleterRequestDescriptor descriptor  = pack(axiStream.tData[valueOf(CQ_DESCRIPTOR_WIDTH)-1:0]);
            case (descriptor.reqType) begin
                MEM_WRITE_REQ: begin
                    if (descriptor.dwordCnt <= valueOf(MAX_DWORD_CNT_OF_CSR) && sideBand.dataByteEn == 4'b1111) begin
                        DmaCsrValue wrValue = axiStream.tData[valueOf(DWORD_WIDTH)-1:0];
                        DmaCsrAddr wrAddr = getAddrFromCqDescriptor(descriptor);
                        let wrReq = DmaCsrFrame {
                            address : wrAddr,
                            value   : wrValue
                        }
                        wrReqFifo.enq(wrReq);
                    end
                    else begin
                        illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
                    end
                end
                MEM_READ_REQ: begin
                    DmaCsrAddr rdAddr = getAddrFromCqDescriptor(descriptor);
                    let npInfo = PcieCompleterRequestNonPostedStore {
                        attributes: descriptor.attributes,
                        trafficClass: descriptor.trafficClass,
                        
                    }
                end
                default: illegalPcieReqCntReg <= illegalPcieReqCntReg + 1;
            end
            
        end
        outFifo.enq(stream);
    endrule
endmodule


module mkCompleterRequest;


endmodule
