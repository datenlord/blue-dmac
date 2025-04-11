import Vector :: *;

interface PrioritySearchBuffer#(numeric type depth, type t_tag, type t_val);
    method Action enq(t_tag tag, t_val value);
    method ActionValue#(Maybe#(t_val)) search(t_tag tag);
endinterface

// A fifo like buffer, if buffer is full, new enq will lead to deq of the oldest element.
// if the same tags exist in the buffer, the newest enququed element will be returned.
module mkPrioritySearchBuffer#(numeric depth)(PrioritySearchBuffer#(depth, t_tag, t_val)) provisos (
    Bits#(t_tag, sz_tag),
    Bits#(t_val, sz_val),
    Eq#(t_tag),
    FShow#(t_tag),
    FShow#(t_val),
    FShow#(Tuple2#(t_tag, t_val))
);
    Vector#(depth, Reg#(Maybe#(Tuple2#(t_tag, t_val)))) bufferVec <- replicateM(mkReg(tagged Invalid));

    method Action enq(t_tag tag, t_val value);
        for (Integer idx=0; idx < valueOf(depth)-1; idx=idx+1) begin
            bufferVec[idx+1] <= bufferVec[idx];
        end
        bufferVec[0] <= tagged Valid tuple2(tag, value);
    endmethod

    method ActionValue#(Maybe#(t_val)) search(t_tag tag);
        Maybe#(t_val) ret = tagged Invalid;
        for (Integer idx=valueOf(depth)-1; idx >=0 ; idx=idx-1) begin
            if (bufferVec[idx] matches tagged Valid .readTuple) begin
                let {readTag, readVal} = readTuple;
                if (readTag == tag) begin
                    ret = tagged Valid readVal;
                end
            end
        end
        return ret;
    endmethod
endmodule