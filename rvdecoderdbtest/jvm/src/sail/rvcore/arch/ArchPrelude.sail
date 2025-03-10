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

// bitfield
bitfield Medeleg : XLENBITS = {
  SAMO_Page_Fault   : 15,
  Load_Page_Fault   : 13,
  Fetch_Page_Fault  : 12,
  MEnvCall          : 11,
  SEnvCall          : 9,
  UEnvCall          : 8,
  SAMO_Access_Fault : 7,
  SAMO_Addr_Align   : 6,
  Load_Access_Fault : 5,
  Load_Addr_Align   : 4,
  Breakpoint        : 3,
  Illegal_Instr     : 2,
  Fetch_Access_Fault: 1,
  Fetch_Addr_Align  : 0
}


