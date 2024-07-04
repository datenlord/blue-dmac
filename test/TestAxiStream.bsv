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
    Reg#(File) fileIn <- mkRegU();
    Reg#(File) fileRef <- mkRegU();
    Reg#(File) fileOut <- mkRegU();
    Reg#(Bool) initFlag <- mkReg(False);
    // Read the file 
    Reg#(Bool) rdDoneFlag <- mkReg(False);
    Reg#(UInt#(32)) rdBatchCnt <- mkReg(0);
    let rdTotalBytesLen = valueOf(RD_BYTES_LENGTH);
    let rdBatchBytesLen = valueOf(BATCH_BYTES);
    let rdLastBatchBytesLen = rdTotalBytesLen % rdBatchBytesLen;
    let rdBatchesNum = rdTotalBytesLen % rdBatchBytesLen > 0 ? rdTotalBytesLen / rdBatchBytesLen + 1 : rdTotalBytesLen / rdBatchBytesLen;
    FIFO#(AxiStream#(BATCH_BYTES, USR_WIDTH)) toDutFifo <- mkSizedFIFO(16);
    // DUT
    AxisFifo#(BATCH_BYTES, USR_WIDTH) dut <- mkTbAxisWire();
    // Control
    Reg#(UInt#(32)) tValidCnt <- mkReg(0);

    rule init(!initFlag);
        initFlag <= True;
        File in <- $fopen("test.txt", "rb");
        File refer <- $fopen("ref.txt", "wb");
        File out <- $fopen("out.txt", "wb");
        if (in == InvalidFile || refer == InvalidFile || out == InvalidFile) begin
            $display("ERROR: couldn't open test file");
            $finish;
        end
        fileIn <= in;
        fileRef <= refer;
        fileOut <= out;
    endrule

    rule readfile(initFlag && !rdDoneFlag && rdBatchCnt < fromInteger(rdBatchesNum));
        Vector#(BATCH_BYTES, Bit#(8)) getChars = replicate(0);
        Bit#(BATCH_BYTES) keep = 0;
        Bool last = False;
        if(rdBatchCnt == fromInteger(rdBatchesNum) - 1) begin  
            for(Integer i = 0; i < rdLastBatchBytesLen; i = i + 1) begin
                int c <- $fgetc(fileIn);
                if(c == -1) begin
                    $fclose(fileIn);
                    $fclose(fileRef);
                end else begin
                    $fwrite(fileRef, "%c", c);
                    getChars[i] = truncate(pack(c));
                    keep[i] = 1'b1;
                end
            end
            $fclose(fileIn);
            $fclose(fileRef);
            rdDoneFlag <= True; 
            last = True;
            $display("INFO: test file read done");
        end else begin
            rdBatchCnt <= rdBatchCnt + 1;
            for(Integer i = 0; i < rdBatchBytesLen; i = i + 1) begin
                int c <- $fgetc(fileIn);
                if(c == -1) begin
                    $fclose(fileRef);
                    $fclose(fileIn);
                    last = True;
                end else begin
                    $fwrite(fileRef, "%c", c);
                    getChars[i] = truncate(pack(c));
                    keep[i] = 1'b1;
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

    rule reader2dut if(rdBatchCnt > 0);
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
            for(Integer i = 0; i < rdBatchBytesLen; i = i + 1) begin
                if(keep[i] == 1'b1) begin $fwrite(fileOut, "%c", getChars[i]); end
            end
        end 
        if(tValidCnt == rdBatchCnt && rdDoneFlag) begin
            $display("INFO: file write done, compare the ref and out")
            $fclose(fileOut);
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


    
