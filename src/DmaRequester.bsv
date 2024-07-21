
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

module mkRequester(Empty);


endmodule