import FIFO::*;

import PcieAxiStreamTypes::*;

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

function Bit#(n) getLowBytes(Bit#(n) data, Bit#(TLog#(TDiv#(n, BYTE_WIDTH))) ptr);
    let temp = data;
    case(ptr)
        1 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        2 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        3 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        4 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        5 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        6 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        7 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        8 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        9 : temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        10: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        11: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        12: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        13: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        14: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        15: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        16: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        17: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        18: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        19: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        20: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        21: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        22: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        23: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        24: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        25: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        26: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        27: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        28: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        29: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        30: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        31: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        32: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        33: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        34: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        35: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        36: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        37: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        38: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        39: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        40: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        41: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        42: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        43: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        44: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        45: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        46: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        47: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        48: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        49: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        50: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        51: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        52: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        53: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        54: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        55: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        56: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        57: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        58: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        59: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        60: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        61: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        62: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        63: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        64: temp = data[valueOf(BYTE_WIDTH)*1-1:0];
        default: temp = 0;
    endcase
    return temp;
endfunction
