// GPR
type regidx  = bits(5)

val read_GPR : regidx -> XLENBITS
scattered function read_GPR

val write_GPR : (regidx, XLENBITS) -> unit
scattered function write_GPR

// CSR
type cregidx = bits(3)
type csreg   = bits(12)

val is_CSR_defined : (csreg) -> bool
scattered function is_CSR_defined

val read_CSR : csreg -> XLENBITS
scattered function read_CSR

val write_CSR : (csreg, XLENBITS) -> XLENBITS
scattered function write_CSR

enum Privilege  = {User, Supervisor, Machine}

