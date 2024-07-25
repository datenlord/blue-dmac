import FIFOF::*;
import Vector::*;

import PcieAxiStreamTypes::*;
import DmaTypes::*;

function Action immAssert(Bool condition, String assertName, Fmt assertFmtMsg);
    action
        let pos = printPosition(getStringPosition(assertName));
        // let pos = printPosition(getEvalPosition(condition));
        if (!condition) begin
            $error(
                "ImmAssert failed in %m @time=%0t: %s-- %s: ",
                $time, pos, assertName, assertFmtMsg
            );
            $finish(1);
        end
    endaction
endfunction

function Data getDataLowBytes(Data data, DataBytePtr ptr);
    Data temp = 0;
    case(ptr)
        1 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*1 -1:0]));
        2 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*2 -1:0]));
        3 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*3 -1:0]));
        4 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*4 -1:0]));
        5 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*5 -1:0]));
        6 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*6 -1:0]));
        7 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*7 -1:0]));
        8 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*8 -1:0]));
        9 : temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*9 -1:0]));
        10: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*10-1:0]));
        11: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*11-1:0]));
        12: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*12-1:0]));
        13: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*13-1:0]));
        14: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*14-1:0]));
        15: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*15-1:0]));
        16: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*16-1:0]));
        17: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*17-1:0]));
        18: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*18-1:0]));
        19: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*19-1:0]));
        20: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*20-1:0]));
        21: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*21-1:0]));
        22: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*22-1:0]));
        23: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*23-1:0]));
        24: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*24-1:0]));
        25: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*25-1:0]));
        26: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*26-1:0]));
        27: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*27-1:0]));
        28: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*28-1:0]));
        29: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*29-1:0]));
        30: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*30-1:0]));
        31: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*31-1:0]));
        32: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*32-1:0]));
        33: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*33-1:0]));
        34: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*34-1:0]));
        35: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*35-1:0]));
        36: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*36-1:0]));
        37: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*37-1:0]));
        38: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*38-1:0]));
        39: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*39-1:0]));
        40: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*40-1:0]));
        41: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*41-1:0]));
        42: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*42-1:0]));
        43: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*43-1:0]));
        44: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*44-1:0]));
        45: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*45-1:0]));
        46: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*46-1:0]));
        47: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*47-1:0]));
        48: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*48-1:0]));
        49: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*49-1:0]));
        50: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*50-1:0]));
        51: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*51-1:0]));
        52: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*52-1:0]));
        53: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*53-1:0]));
        54: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*54-1:0]));
        55: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*55-1:0]));
        56: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*56-1:0]));
        57: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*57-1:0]));
        58: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*58-1:0]));
        59: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*59-1:0]));
        60: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*60-1:0]));
        61: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*61-1:0]));
        62: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*62-1:0]));
        63: temp = zeroExtend(Data'(data[valueOf(BYTE_WIDTH)*63-1:0]));
        default: temp = 0;
    endcase
    return temp;
endfunction

function Data getDataHighBytes(Data data, DataBytePtr ptr);
    Data temp = 0;
    case(ptr)
        1 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*1 ]));
        2 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*2 ]));
        3 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*3 ]));
        4 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*4 ]));
        5 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*5 ]));
        6 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*6 ]));
        7 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*7 ]));
        8 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*8 ]));
        9 : temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*9 ]));
        10: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*10]));
        11: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*11]));
        12: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*12]));
        13: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*13]));
        14: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*14]));
        15: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*15]));
        16: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*16]));
        17: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*17]));
        18: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*18]));
        19: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*19]));
        20: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*20]));
        21: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*21]));
        22: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*22]));
        23: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*23]));
        24: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*24]));
        25: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*25]));
        26: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*26]));
        27: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*27]));
        28: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*28]));
        29: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*29]));
        30: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*30]));
        31: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*31]));
        32: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*32]));
        33: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*33]));
        34: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*34]));
        35: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*35]));
        36: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*36]));
        37: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*37]));
        38: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*38]));
        39: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*39]));
        40: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*40]));
        41: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*41]));
        42: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*42]));
        43: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*43]));
        44: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*44]));
        45: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*45]));
        46: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*46]));
        47: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*47]));
        48: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*48]));
        49: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*49]));
        50: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*50]));
        51: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*51]));
        52: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*52]));
        53: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*53]));
        54: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*54]));
        55: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*55]));
        56: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*56]));
        57: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*57]));
        58: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*58]));
        59: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*59]));
        60: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*60]));
        61: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*61]));
        62: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*62]));
        63: temp = zeroExtend(Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*63]));
        default: temp = data;
    endcase
    return temp;
endfunction

function DmaMemAddr getAddrLowBits(DmaMemAddr addr, Bit#(TLog#(DMA_MEM_ADDR_WIDTH)) ptr);
    DmaMemAddr temp = 0;
    case(ptr)
        1 : temp = zeroExtend(DmaMemAddr'(addr[1 -1:0]));
        2 : temp = zeroExtend(DmaMemAddr'(addr[2 -1:0]));
        3 : temp = zeroExtend(DmaMemAddr'(addr[3 -1:0]));
        4 : temp = zeroExtend(DmaMemAddr'(addr[4 -1:0]));
        5 : temp = zeroExtend(DmaMemAddr'(addr[5 -1:0]));
        6 : temp = zeroExtend(DmaMemAddr'(addr[6 -1:0]));
        7 : temp = zeroExtend(DmaMemAddr'(addr[7 -1:0]));
        8 : temp = zeroExtend(DmaMemAddr'(addr[8 -1:0]));
        9 : temp = zeroExtend(DmaMemAddr'(addr[9 -1:0]));
        10: temp = zeroExtend(DmaMemAddr'(addr[10-1:0]));
        11: temp = zeroExtend(DmaMemAddr'(addr[11-1:0]));
        12: temp = zeroExtend(DmaMemAddr'(addr[12-1:0]));
        13: temp = zeroExtend(DmaMemAddr'(addr[13-1:0]));
        14: temp = zeroExtend(DmaMemAddr'(addr[14-1:0]));
        15: temp = zeroExtend(DmaMemAddr'(addr[15-1:0]));
        16: temp = zeroExtend(DmaMemAddr'(addr[16-1:0]));
        17: temp = zeroExtend(DmaMemAddr'(addr[17-1:0]));
        18: temp = zeroExtend(DmaMemAddr'(addr[18-1:0]));
        19: temp = zeroExtend(DmaMemAddr'(addr[19-1:0]));
        20: temp = zeroExtend(DmaMemAddr'(addr[20-1:0]));
        21: temp = zeroExtend(DmaMemAddr'(addr[21-1:0]));
        22: temp = zeroExtend(DmaMemAddr'(addr[22-1:0]));
        23: temp = zeroExtend(DmaMemAddr'(addr[23-1:0]));
        24: temp = zeroExtend(DmaMemAddr'(addr[24-1:0]));
        25: temp = zeroExtend(DmaMemAddr'(addr[25-1:0]));
        26: temp = zeroExtend(DmaMemAddr'(addr[26-1:0]));
        27: temp = zeroExtend(DmaMemAddr'(addr[27-1:0]));
        28: temp = zeroExtend(DmaMemAddr'(addr[28-1:0]));
        29: temp = zeroExtend(DmaMemAddr'(addr[29-1:0]));
        30: temp = zeroExtend(DmaMemAddr'(addr[30-1:0]));
        31: temp = zeroExtend(DmaMemAddr'(addr[31-1:0]));
        32: temp = zeroExtend(DmaMemAddr'(addr[32-1:0]));
        33: temp = zeroExtend(DmaMemAddr'(addr[33-1:0]));
        34: temp = zeroExtend(DmaMemAddr'(addr[34-1:0]));
        35: temp = zeroExtend(DmaMemAddr'(addr[35-1:0]));
        36: temp = zeroExtend(DmaMemAddr'(addr[36-1:0]));
        37: temp = zeroExtend(DmaMemAddr'(addr[37-1:0]));
        38: temp = zeroExtend(DmaMemAddr'(addr[38-1:0]));
        39: temp = zeroExtend(DmaMemAddr'(addr[39-1:0]));
        40: temp = zeroExtend(DmaMemAddr'(addr[40-1:0]));
        41: temp = zeroExtend(DmaMemAddr'(addr[41-1:0]));
        42: temp = zeroExtend(DmaMemAddr'(addr[42-1:0]));
        43: temp = zeroExtend(DmaMemAddr'(addr[43-1:0]));
        44: temp = zeroExtend(DmaMemAddr'(addr[44-1:0]));
        45: temp = zeroExtend(DmaMemAddr'(addr[45-1:0]));
        46: temp = zeroExtend(DmaMemAddr'(addr[46-1:0]));
        47: temp = zeroExtend(DmaMemAddr'(addr[47-1:0]));
        48: temp = zeroExtend(DmaMemAddr'(addr[48-1:0]));
        49: temp = zeroExtend(DmaMemAddr'(addr[49-1:0]));
        50: temp = zeroExtend(DmaMemAddr'(addr[50-1:0]));
        51: temp = zeroExtend(DmaMemAddr'(addr[51-1:0]));
        52: temp = zeroExtend(DmaMemAddr'(addr[52-1:0]));
        53: temp = zeroExtend(DmaMemAddr'(addr[53-1:0]));
        54: temp = zeroExtend(DmaMemAddr'(addr[54-1:0]));
        55: temp = zeroExtend(DmaMemAddr'(addr[55-1:0]));
        56: temp = zeroExtend(DmaMemAddr'(addr[56-1:0]));
        57: temp = zeroExtend(DmaMemAddr'(addr[57-1:0]));
        58: temp = zeroExtend(DmaMemAddr'(addr[58-1:0]));
        59: temp = zeroExtend(DmaMemAddr'(addr[59-1:0]));
        60: temp = zeroExtend(DmaMemAddr'(addr[60-1:0]));
        61: temp = zeroExtend(DmaMemAddr'(addr[61-1:0]));
        62: temp = zeroExtend(DmaMemAddr'(addr[62-1:0]));
        63: temp = zeroExtend(DmaMemAddr'(addr[63-1:0]));
        default: temp = 0;
    endcase
    return temp;
endfunction

typedef 32 CNTFIFO_SIZE_WIDTH;
typedef UInt#(CNTFIFO_SIZE_WIDTH) FifoSize;

interface CounteredFIFOF#(type t);
    method Action enq (t x);
    method Action deq;
    method t first;
    method Action clear;
    method Bool notFull;
    method Bool notEmpty;
    method FifoSize getCurSize;
endinterface

module mkCounteredFIFOF#(Integer depth)(CounteredFIFOF#(t)) provisos(Bits#(t, tSz));
    Wire#(Bool) hasDeqCall  <- mkDWire(False);
    Wire#(Bool) hasEnqCall  <- mkDWire(False);
    Reg#(FifoSize) curSize <- mkReg(0);
    FIFOF#(t) fifo <- mkSizedFIFOF(depth);

    rule updateSize;
        case({pack(hasEnqCall), pack(hasDeqCall)})
            2'b10:   curSize <= curSize + 1;
            2'b01:   curSize <= curSize -1;
            default: curSize <= curSize;
        endcase
    endrule

    method Action enq (t x);
        fifo.enq(x);
        hasEnqCall <= True;
    endmethod

    method Action deq;
        fifo.deq;
        hasDeqCall <= True;
    endmethod

    method t first = fifo.first;
    method Action clear  = fifo.clear;
    method Bool notFull  = fifo.notFull;
    method Bool notEmpty = fifo.notEmpty;

    method FifoSize getCurSize = curSize;
endmodule

function ByteParity calByteParity(Byte data);
    return (data[0] ^ data[1]  ^ data[2] ^ data[3] ^ data[4] ^ data[5] ^ data[6] ^ data[7]);
endfunction

typedef Bit#(BYTE_EN_WIDTH) DataParity;
typedef Bit#(TDiv#(DWORD_WIDTH, BYTE_WIDTH)) DwordParity;

function DataParity calDataParity(Data data);
    Vector#(BYTE_EN_WIDTH, Byte) dataBytes = unpack(data);
    Vector#(BYTE_EN_WIDTH, ByteParity) dataParities= newVector();
    for (Integer idx = 0; idx < valueOf(BYTE_EN_WIDTH); idx = idx + 1) begin
        dataParities[idx] = calByteParity(dataBytes[idx]);
    end
    return pack(dataParities);
endfunction