import FIFO::*;
import Vector::*;
import AxiStreamTypes::*;
import Counter::*;

typedef 512 DATA_WIDTH;
typedef TDiv#(DATA_WIDTH, 8) BATCH_BYTES;
typedef 128 USR_WIDTH;
typedef 4321 RD_BYTES_LENGTH;


interface AxisFifo#(numeric type keepWidth, numeric type usrWidth);
    interface RawAxiStreamMaster#(keepWidth, usrWidth) axisMaster;
    interface RawAxiStreamSlave#(keepWidth, usrWidth) axisSlave;
endinterface


module mkTbAxisRdWrLoop (Empty);
    Reg#(File) fileInReg <- mkRegU();
    Reg#(File) fileRefReg <- mkRegU();
    Reg#(File) fileOutReg <- mkRegU();
    Reg#(Bool) initFlagReg <- mkReg(False);
    // Read the file 
    Reg#(Bool) rdDoneFlagReg <- mkReg(False);
    Reg#(UInt#(32)) rdBatchCntReg <- mkReg(0);
    let rdTotalBytesLen = valueOf(RD_BYTES_LENGTH);
    let rdBatchBytesLen = valueOf(BATCH_BYTES);
    let rdLastBatchBytesLen = rdTotalBytesLen % rdBatchBytesLen;
    let rdBatchesNum = rdTotalBytesLen % rdBatchBytesLen > 0 ? rdTotalBytesLen / rdBatchBytesLen + 1 : rdTotalBytesLen / rdBatchBytesLen;
    FIFO#(AxiStream#(BATCH_BYTES, USR_WIDTH)) toDutFifo <- mkSizedFIFO(16);
    // DUT
    AxisFifo#(BATCH_BYTES, USR_WIDTH) dut <- mkTbAxisWire();
    // Control
    Reg#(UInt#(32)) tValidCnt <- mkReg(0);

    rule init(!initFlagReg);
        initFlagReg <= True;
        File in <- $fopen("test.txt", "rb");
        File refer <- $fopen("ref.txt", "wb");
        File out <- $fopen("out.txt", "wb");
        if (in == InvalidFile || refer == InvalidFile || out == InvalidFile) begin
            $display("ERROR: couldn't open test file");
            $finish;
        end
        fileInReg <= in;
        fileRefReg <= refer;
        fileOutReg <= out;
    endrule

    rule readfile(initFlagReg && !rdDoneFlagReg && rdBatchCntReg < fromInteger(rdBatchesNum));
        Vector#(BATCH_BYTES, Bit#(8)) getChars = replicate(0);
        Bit#(BATCH_BYTES) keep = 0;
        Bool last = False;
        if(rdBatchCntReg == fromInteger(rdBatchesNum) - 1) begin  
            for(Integer idx = 0; idx < rdLastBatchBytesLen; idx = idx + 1) begin
                int c <- $fgetc(fileInReg);
                if(c == -1) begin
                    $fclose(fileInReg);
                    $fclose(fileRefReg);
                end else begin
                    $fwrite(fileRefReg, "%c", c);
                    getChars[idx] = truncate(pack(c));
                    keep[idx] = 1'b1;
                end
            end
            $fclose(fileInReg);
            $fclose(fileRefReg);
            rdDoneFlagReg <= True; 
            last = True;
            $display("INFO: test file read done");
        end else begin
            rdBatchCntReg <= rdBatchCntReg + 1;
            for(Integer idx = 0; idx < rdBatchBytesLen; idx = idx + 1) begin
                int rdChar <- $fgetc(fileInReg);
                if(rdChar == -1) begin
                    $fclose(fileRefReg);
                    $fclose(fileInReg);
                    last = True;
                end else begin
                    $fwrite(fileRefReg, "%c", rdChar);
                    getChars[idx] = truncate(pack(rdChar));
                    keep[idx] = 1'b1;
                end
            end
        end
        let axis = AxiStream{
                tData: pack(getChars),
                tKeep: keep,
                tLast: last,
                tUser: 0
            };
        toDutFifo.enq(axis);
    endrule

    rule reader2dut if(rdBatchCntReg > 0);
        if(dut.axisSlave.tReady) begin
            // $display("INFO: simulation exec a batch");
            toDutFifo.deq();
            let axis = toDutFifo.first;
            dut.axisSlave.tValid(
                True,
                axis.tData,
                axis.tKeep,
                axis.tLast,
                axis.tUser);
        end    
    endrule

    rule dut2writer;
        dut.axisMaster.tReady(True);
        if(dut.axisMaster.tValid) begin
            tValidCnt <= tValidCnt + 1;
            let data = dut.axisMaster.tData;
            Vector#(BATCH_BYTES, Bit#(8)) getChars = unpack(data);
            let keep = dut.axisMaster.tKeep;
            for(Integer idx = 0; idx < rdBatchBytesLen; idx = idx + 1) begin
                if(keep[idx] == 1'b1) begin $fwrite(fileOutReg, "%c", getChars[i]); end
            end
        end 
        if(tValidCnt == rdBatchCntReg && rdDoneFlagReg) begin
            $display("INFO: file write done, compare the ref and out")
            $fclose(fileOutReg);
            $finish();
        end
    endrule

endmodule

module mkTbAxisWire(AxisFifo#(keepWidth, usrWidth) ifc);
    Wire#(Bit#(TMul#(keepWidth, 8))) data <- mkDWire(0);
    Wire#(Bit#(keepWidth)) keep <- mkDWire(0);
    Wire#(Bit#(usrWidth)) user <- mkDWire(0);
    Wire#(Bit#(1)) last <- mkDWire(0);
    Wire#(Bit#(1)) rdy <- mkDWire(0);
    Wire#(Bit#(1)) vld <- mkDWire(0);

    interface RawAxiStreamMaster axisMaster;
        method Bool tValid = unpack(vld);
        method Bool tLast = unpack(last);
        method Bit#(TMul#(keepWidth, 8)) tData = data;
        method Bit#(keepWidth) tKeep = keep;
        method Bit#(usrWidth) tUser = user;
        method Action tReady(Bool ready);
            rdy <= pack(ready);
        endmethod   
    endinterface

    interface RawAxiStreamSlave axisSlave;
        method Bool tReady = True;
        method Action tValid(
            Bool                      tvalid,
            Bit#(TMul#(keepWidth, 8)) tData,
            Bit#(keepWidth)           tKeep,
            Bool                      tLast,
            Bit#(usrWidth)            tUser
        );
            data <= tData;
            keep <= tKeep;
            user <= tUser;
            last <= pack(tLast);
            vld <= pack(tvalid);
        endmethod
    endinterface
endmodule

// module mkTbAxisPipeFifo (AxisFifo#(keepWidth, usrWidth) ifc);
//     FIFOF#(AxiStream#(keepWidth, usrWidth)) <- mkSizedFIFOF(10); 

// endmodule


    
