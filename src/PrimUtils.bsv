import FIFOF::*;

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
        1 : temp[valueOf(BYTE_WIDTH)*1 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*1 -1:0]);
        2 : temp[valueOf(BYTE_WIDTH)*2 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*2 -1:0]);
        3 : temp[valueOf(BYTE_WIDTH)*3 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*3 -1:0]);
        4 : temp[valueOf(BYTE_WIDTH)*4 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*4 -1:0]);
        5 : temp[valueOf(BYTE_WIDTH)*5 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*5 -1:0]);
        6 : temp[valueOf(BYTE_WIDTH)*6 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*6 -1:0]);
        7 : temp[valueOf(BYTE_WIDTH)*7 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*7 -1:0]);
        8 : temp[valueOf(BYTE_WIDTH)*8 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*8 -1:0]);
        9 : temp[valueOf(BYTE_WIDTH)*9 -1:0] = Data'(data[valueOf(BYTE_WIDTH)*9 -1:0]);
        10: temp[valueOf(BYTE_WIDTH)*10-1:0] = Data'(data[valueOf(BYTE_WIDTH)*10-1:0]);
        11: temp[valueOf(BYTE_WIDTH)*11-1:0] = Data'(data[valueOf(BYTE_WIDTH)*11-1:0]);
        12: temp[valueOf(BYTE_WIDTH)*12-1:0] = Data'(data[valueOf(BYTE_WIDTH)*12-1:0]);
        13: temp[valueOf(BYTE_WIDTH)*13-1:0] = Data'(data[valueOf(BYTE_WIDTH)*13-1:0]);
        14: temp[valueOf(BYTE_WIDTH)*14-1:0] = Data'(data[valueOf(BYTE_WIDTH)*14-1:0]);
        15: temp[valueOf(BYTE_WIDTH)*15-1:0] = Data'(data[valueOf(BYTE_WIDTH)*15-1:0]);
        16: temp[valueOf(BYTE_WIDTH)*16-1:0] = Data'(data[valueOf(BYTE_WIDTH)*16-1:0]);
        17: temp[valueOf(BYTE_WIDTH)*17-1:0] = Data'(data[valueOf(BYTE_WIDTH)*17-1:0]);
        18: temp[valueOf(BYTE_WIDTH)*18-1:0] = Data'(data[valueOf(BYTE_WIDTH)*18-1:0]);
        19: temp[valueOf(BYTE_WIDTH)*19-1:0] = Data'(data[valueOf(BYTE_WIDTH)*19-1:0]);
        20: temp[valueOf(BYTE_WIDTH)*20-1:0] = Data'(data[valueOf(BYTE_WIDTH)*20-1:0]);
        21: temp[valueOf(BYTE_WIDTH)*21-1:0] = Data'(data[valueOf(BYTE_WIDTH)*21-1:0]);
        22: temp[valueOf(BYTE_WIDTH)*22-1:0] = Data'(data[valueOf(BYTE_WIDTH)*22-1:0]);
        23: temp[valueOf(BYTE_WIDTH)*23-1:0] = Data'(data[valueOf(BYTE_WIDTH)*23-1:0]);
        24: temp[valueOf(BYTE_WIDTH)*24-1:0] = Data'(data[valueOf(BYTE_WIDTH)*24-1:0]);
        25: temp[valueOf(BYTE_WIDTH)*25-1:0] = Data'(data[valueOf(BYTE_WIDTH)*25-1:0]);
        26: temp[valueOf(BYTE_WIDTH)*26-1:0] = Data'(data[valueOf(BYTE_WIDTH)*26-1:0]);
        27: temp[valueOf(BYTE_WIDTH)*27-1:0] = Data'(data[valueOf(BYTE_WIDTH)*27-1:0]);
        28: temp[valueOf(BYTE_WIDTH)*28-1:0] = Data'(data[valueOf(BYTE_WIDTH)*28-1:0]);
        29: temp[valueOf(BYTE_WIDTH)*29-1:0] = Data'(data[valueOf(BYTE_WIDTH)*29-1:0]);
        30: temp[valueOf(BYTE_WIDTH)*30-1:0] = Data'(data[valueOf(BYTE_WIDTH)*30-1:0]);
        31: temp[valueOf(BYTE_WIDTH)*31-1:0] = Data'(data[valueOf(BYTE_WIDTH)*31-1:0]);
        32: temp[valueOf(BYTE_WIDTH)*32-1:0] = Data'(data[valueOf(BYTE_WIDTH)*32-1:0]);
        33: temp[valueOf(BYTE_WIDTH)*33-1:0] = Data'(data[valueOf(BYTE_WIDTH)*33-1:0]);
        34: temp[valueOf(BYTE_WIDTH)*34-1:0] = Data'(data[valueOf(BYTE_WIDTH)*34-1:0]);
        35: temp[valueOf(BYTE_WIDTH)*35-1:0] = Data'(data[valueOf(BYTE_WIDTH)*35-1:0]);
        36: temp[valueOf(BYTE_WIDTH)*36-1:0] = Data'(data[valueOf(BYTE_WIDTH)*36-1:0]);
        37: temp[valueOf(BYTE_WIDTH)*37-1:0] = Data'(data[valueOf(BYTE_WIDTH)*37-1:0]);
        38: temp[valueOf(BYTE_WIDTH)*38-1:0] = Data'(data[valueOf(BYTE_WIDTH)*38-1:0]);
        39: temp[valueOf(BYTE_WIDTH)*39-1:0] = Data'(data[valueOf(BYTE_WIDTH)*39-1:0]);
        40: temp[valueOf(BYTE_WIDTH)*40-1:0] = Data'(data[valueOf(BYTE_WIDTH)*40-1:0]);
        41: temp[valueOf(BYTE_WIDTH)*41-1:0] = Data'(data[valueOf(BYTE_WIDTH)*41-1:0]);
        42: temp[valueOf(BYTE_WIDTH)*42-1:0] = Data'(data[valueOf(BYTE_WIDTH)*42-1:0]);
        43: temp[valueOf(BYTE_WIDTH)*43-1:0] = Data'(data[valueOf(BYTE_WIDTH)*43-1:0]);
        44: temp[valueOf(BYTE_WIDTH)*44-1:0] = Data'(data[valueOf(BYTE_WIDTH)*44-1:0]);
        45: temp[valueOf(BYTE_WIDTH)*45-1:0] = Data'(data[valueOf(BYTE_WIDTH)*45-1:0]);
        46: temp[valueOf(BYTE_WIDTH)*46-1:0] = Data'(data[valueOf(BYTE_WIDTH)*46-1:0]);
        47: temp[valueOf(BYTE_WIDTH)*47-1:0] = Data'(data[valueOf(BYTE_WIDTH)*47-1:0]);
        48: temp[valueOf(BYTE_WIDTH)*48-1:0] = Data'(data[valueOf(BYTE_WIDTH)*48-1:0]);
        49: temp[valueOf(BYTE_WIDTH)*49-1:0] = Data'(data[valueOf(BYTE_WIDTH)*49-1:0]);
        50: temp[valueOf(BYTE_WIDTH)*50-1:0] = Data'(data[valueOf(BYTE_WIDTH)*50-1:0]);
        51: temp[valueOf(BYTE_WIDTH)*51-1:0] = Data'(data[valueOf(BYTE_WIDTH)*51-1:0]);
        52: temp[valueOf(BYTE_WIDTH)*52-1:0] = Data'(data[valueOf(BYTE_WIDTH)*52-1:0]);
        53: temp[valueOf(BYTE_WIDTH)*53-1:0] = Data'(data[valueOf(BYTE_WIDTH)*53-1:0]);
        54: temp[valueOf(BYTE_WIDTH)*54-1:0] = Data'(data[valueOf(BYTE_WIDTH)*54-1:0]);
        55: temp[valueOf(BYTE_WIDTH)*55-1:0] = Data'(data[valueOf(BYTE_WIDTH)*55-1:0]);
        56: temp[valueOf(BYTE_WIDTH)*56-1:0] = Data'(data[valueOf(BYTE_WIDTH)*56-1:0]);
        57: temp[valueOf(BYTE_WIDTH)*57-1:0] = Data'(data[valueOf(BYTE_WIDTH)*57-1:0]);
        58: temp[valueOf(BYTE_WIDTH)*58-1:0] = Data'(data[valueOf(BYTE_WIDTH)*58-1:0]);
        59: temp[valueOf(BYTE_WIDTH)*59-1:0] = Data'(data[valueOf(BYTE_WIDTH)*59-1:0]);
        60: temp[valueOf(BYTE_WIDTH)*60-1:0] = Data'(data[valueOf(BYTE_WIDTH)*60-1:0]);
        61: temp[valueOf(BYTE_WIDTH)*61-1:0] = Data'(data[valueOf(BYTE_WIDTH)*61-1:0]);
        62: temp[valueOf(BYTE_WIDTH)*62-1:0] = Data'(data[valueOf(BYTE_WIDTH)*62-1:0]);
        63: temp[valueOf(BYTE_WIDTH)*63-1:0] = Data'(data[valueOf(BYTE_WIDTH)*63-1:0]);
        default: temp = 0;
    endcase
    return temp;
endfunction

function Data getDataHighBytes(Data data, DataBytePtr ptr);
    Data temp = 0;
    case(ptr)
        1 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*1 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*1 ]);
        2 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*2 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*2 ]);
        3 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*3 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*3 ]);
        4 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*4 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*4 ]);
        5 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*5 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*5 ]);
        6 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*6 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*6 ]);
        7 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*7 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*7 ]);
        8 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*8 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*8 ]);
        9 : temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*9 ] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*9 ]);
        10: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*10] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*10]);
        11: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*11] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*11]);
        12: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*12] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*12]);
        13: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*13] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*13]);
        14: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*14] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*14]);
        15: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*15] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*15]);
        16: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*16] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*16]);
        17: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*17] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*17]);
        18: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*18] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*18]);
        19: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*19] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*19]);
        20: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*20] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*20]);
        21: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*21] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*21]);
        22: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*22] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*22]);
        23: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*23] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*23]);
        24: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*24] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*24]);
        25: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*25] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*25]);
        26: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*26] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*26]);
        27: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*27] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*27]);
        28: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*28] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*28]);
        29: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*29] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*29]);
        30: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*30] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*30]);
        31: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*31] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*31]);
        32: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*32] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*32]);
        33: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*33] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*33]);
        34: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*34] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*34]);
        35: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*35] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*35]);
        36: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*36] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*36]);
        37: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*37] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*37]);
        38: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*38] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*38]);
        39: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*39] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*39]);
        40: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*40] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*40]);
        41: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*41] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*41]);
        42: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*42] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*42]);
        43: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*43] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*43]);
        44: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*44] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*44]);
        45: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*45] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*45]);
        46: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*46] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*46]);
        47: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*47] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*47]);
        48: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*48] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*48]);
        49: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*49] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*49]);
        50: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*50] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*50]);
        51: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*51] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*51]);
        52: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*52] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*52]);
        53: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*53] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*53]);
        54: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*54] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*54]);
        55: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*55] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*55]);
        56: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*56] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*56]);
        57: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*57] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*57]);
        58: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*58] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*58]);
        59: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*59] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*59]);
        60: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*60] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*60]);
        61: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*61] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*61]);
        62: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*62] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*62]);
        63: temp[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*63] = Data'(data[valueOf(DATA_WIDTH)-1:valueOf(DATA_WIDTH)-valueOf(BYTE_WIDTH)*63]);
        default: temp = data;
    endcase
    return temp;
endfunction

function DmaMemAddr getAddrLowBits(DmaMemAddr addr, Bit#(TLog#(DMA_MEM_ADDR_WIDTH)) ptr);
    DmaMemAddr temp = 0;
    case(ptr)
        1 : temp[1 -1:0] = DmaMemAddr'(addr[1 -1:0]);
        2 : temp[2 -1:0] = DmaMemAddr'(addr[2 -1:0]);
        3 : temp[3 -1:0] = DmaMemAddr'(addr[3 -1:0]);
        4 : temp[4 -1:0] = DmaMemAddr'(addr[4 -1:0]);
        5 : temp[5 -1:0] = DmaMemAddr'(addr[5 -1:0]);
        6 : temp[6 -1:0] = DmaMemAddr'(addr[6 -1:0]);
        7 : temp[7 -1:0] = DmaMemAddr'(addr[7 -1:0]);
        8 : temp[8 -1:0] = DmaMemAddr'(addr[8 -1:0]);
        9 : temp[9 -1:0] = DmaMemAddr'(addr[9 -1:0]);
        10: temp[10-1:0] = DmaMemAddr'(addr[10-1:0]);
        11: temp[11-1:0] = DmaMemAddr'(addr[11-1:0]);
        12: temp[12-1:0] = DmaMemAddr'(addr[12-1:0]);
        13: temp[13-1:0] = DmaMemAddr'(addr[13-1:0]);
        14: temp[14-1:0] = DmaMemAddr'(addr[14-1:0]);
        15: temp[15-1:0] = DmaMemAddr'(addr[15-1:0]);
        16: temp[16-1:0] = DmaMemAddr'(addr[16-1:0]);
        17: temp[17-1:0] = DmaMemAddr'(addr[17-1:0]);
        18: temp[18-1:0] = DmaMemAddr'(addr[18-1:0]);
        19: temp[19-1:0] = DmaMemAddr'(addr[19-1:0]);
        20: temp[20-1:0] = DmaMemAddr'(addr[20-1:0]);
        21: temp[21-1:0] = DmaMemAddr'(addr[21-1:0]);
        22: temp[22-1:0] = DmaMemAddr'(addr[22-1:0]);
        23: temp[23-1:0] = DmaMemAddr'(addr[23-1:0]);
        24: temp[24-1:0] = DmaMemAddr'(addr[24-1:0]);
        25: temp[25-1:0] = DmaMemAddr'(addr[25-1:0]);
        26: temp[26-1:0] = DmaMemAddr'(addr[26-1:0]);
        27: temp[27-1:0] = DmaMemAddr'(addr[27-1:0]);
        28: temp[28-1:0] = DmaMemAddr'(addr[28-1:0]);
        29: temp[29-1:0] = DmaMemAddr'(addr[29-1:0]);
        30: temp[30-1:0] = DmaMemAddr'(addr[30-1:0]);
        31: temp[31-1:0] = DmaMemAddr'(addr[31-1:0]);
        32: temp[32-1:0] = DmaMemAddr'(addr[32-1:0]);
        33: temp[33-1:0] = DmaMemAddr'(addr[33-1:0]);
        34: temp[34-1:0] = DmaMemAddr'(addr[34-1:0]);
        35: temp[35-1:0] = DmaMemAddr'(addr[35-1:0]);
        36: temp[36-1:0] = DmaMemAddr'(addr[36-1:0]);
        37: temp[37-1:0] = DmaMemAddr'(addr[37-1:0]);
        38: temp[38-1:0] = DmaMemAddr'(addr[38-1:0]);
        39: temp[39-1:0] = DmaMemAddr'(addr[39-1:0]);
        40: temp[40-1:0] = DmaMemAddr'(addr[40-1:0]);
        41: temp[41-1:0] = DmaMemAddr'(addr[41-1:0]);
        42: temp[42-1:0] = DmaMemAddr'(addr[42-1:0]);
        43: temp[43-1:0] = DmaMemAddr'(addr[43-1:0]);
        44: temp[44-1:0] = DmaMemAddr'(addr[44-1:0]);
        45: temp[45-1:0] = DmaMemAddr'(addr[45-1:0]);
        46: temp[46-1:0] = DmaMemAddr'(addr[46-1:0]);
        47: temp[47-1:0] = DmaMemAddr'(addr[47-1:0]);
        48: temp[48-1:0] = DmaMemAddr'(addr[48-1:0]);
        49: temp[49-1:0] = DmaMemAddr'(addr[49-1:0]);
        50: temp[50-1:0] = DmaMemAddr'(addr[50-1:0]);
        51: temp[51-1:0] = DmaMemAddr'(addr[51-1:0]);
        52: temp[52-1:0] = DmaMemAddr'(addr[52-1:0]);
        53: temp[53-1:0] = DmaMemAddr'(addr[53-1:0]);
        54: temp[54-1:0] = DmaMemAddr'(addr[54-1:0]);
        55: temp[55-1:0] = DmaMemAddr'(addr[55-1:0]);
        56: temp[56-1:0] = DmaMemAddr'(addr[56-1:0]);
        57: temp[57-1:0] = DmaMemAddr'(addr[57-1:0]);
        58: temp[58-1:0] = DmaMemAddr'(addr[58-1:0]);
        59: temp[59-1:0] = DmaMemAddr'(addr[59-1:0]);
        60: temp[60-1:0] = DmaMemAddr'(addr[60-1:0]);
        61: temp[61-1:0] = DmaMemAddr'(addr[61-1:0]);
        62: temp[62-1:0] = DmaMemAddr'(addr[62-1:0]);
        63: temp[63-1:0] = DmaMemAddr'(addr[63-1:0]);
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
    Reg#(FifoSize) curSize <- mkReg(0);
    FIFOF#(t) fifo <- mkSizedFIFOF(depth);

    method Action enq (t x);
        fifo.enq(x);
        curSize <= curSize + 1;
    endmethod

    method Action deq;
        fifo.deq;
        curSize <= curSize - 1;
    endmethod

    method t first = fifo.first;
    method Action clear  = fifo.clear;
    method Bool notFull  = fifo.notFull;
    method Bool notEmpty = fifo.notEmpty;

    method FifoSize getCurSize = curSize;
endmodule

