function sys_enable_writable_misa() : unit -> bool = true
function ext_veto_disable_C() : unit -> bool = false
function sys_enable_rvc() : unit -> bool = true
function sys_enable_fdext() : unit -> bool = false
function sys_enable_zfinx() : unit -> bool = false
function sys_enable_writable_fiom() : unit -> bool = false
function sys_writable_hpm_counters() : unit -> bits(32) = {
  0xffffffff
}

function get_vlen_pow() -> range(3, 16) = 9