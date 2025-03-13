val inst_fetch = pure "inst_fetch" : XLENBITS -> bits(32)
val get_mip = pure "get_mip" : unit -> bits(64)
val get_sip = pure "get_sip" : unit -> bits(64)
val fence_i = pure "fence_i" : (bits(4), bits(4)) -> unit
