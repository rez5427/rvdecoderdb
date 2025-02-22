// regfile r/w

function rX (r : regno) -> xlenbits = {
  let v : regtype =
    match r {
      0 => zero_reg,
      1 => x1,
      2 => x2,
      3 => x3,
      4 => x4,
      5 => x5,
      6 => x6,
      7 => x7,
      8 => x8,
      9 => x9,
      10 => x10,
      11 => x11,
      12 => x12,
      13 => x13,
      14 => x14,
      15 => x15,
      16 => x16,
      17 => x17,
      18 => x18,
      19 => x19,
      20 => x20,
      21 => x21,
      22 => x22,
      23 => x23,
      24 => x24,
      25 => x25,
      26 => x26,
      27 => x27,
      28 => x28,
      29 => x29,
      30 => x30,
      31 => x31,
      _  => {assert(false, "invalid register number"); zero_reg}
    };
  regval_from_reg(v)
}

function wX (r : regno, in_v : xlenbits) -> unit = {
  let v = regval_into_reg(in_v);
  match r {
    0  => (),
    1  => x1 = v,
    2  => x2 = v,
    3  => x3 = v,
    4  => x4 = v,
    5  => x5 = v,
    6  => x6 = v,
    7  => x7 = v,
    8  => x8 = v,
    9  => x9 = v,
    10 => x10 = v,
    11 => x11 = v,
    12 => x12 = v,
    13 => x13 = v,
    14 => x14 = v,
    15 => x15 = v,
    16 => x16 = v,
    17 => x17 = v,
    18 => x18 = v,
    19 => x19 = v,
    20 => x20 = v,
    21 => x21 = v,
    22 => x22 = v,
    23 => x23 = v,
    24 => x24 = v,
    25 => x25 = v,
    26 => x26 = v,
    27 => x27 = v,
    28 => x28 = v,
    29 => x29 = v,
    30 => x30 = v,
    31 => x31 = v,
    _  => assert(false, "invalid register number")
  };
  ()
}

function rX_bits(i: regidx) -> xlenbits = rX(unsigned(i))

function wX_bits(i: regidx, data: xlenbits) -> unit = {
  wX(unsigned(i)) = data
}

overload X = {rX_bits, wX_bits, rX, wX}



function legalize_mip(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  /* The only writable bits are the S-mode bits, and with the 'N'
   * extension, the U-mode bits. */
  let v = Mk_Minterrupts(v);
  [o with
    SEI = if extensionEnabled(Ext_S) then v[SEI] else 0b0,
    SSI = if extensionEnabled(Ext_S) then v[SSI] else 0b0,
    STI = if extensionEnabled(Ext_S) then (
      // STI is read only if Sstc is enabled and STCE is set (it is equal to stimecmp <= mtime).
      if extensionEnabled(Ext_Sstc) & menvcfg[STCE] == 0b1 then o[STI] else v[STI]
    ) else 0b0,
  ]
}

function legalize_mie(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  let v = Mk_Minterrupts(v);
  [o with
    MEI = v[MEI],
    MTI = v[MTI],
    MSI = v[MSI],
    SEI = if extensionEnabled(Ext_S) then v[SEI] else 0b0,
    STI = if extensionEnabled(Ext_S) then v[STI] else 0b0,
    SSI = if extensionEnabled(Ext_S) then v[SSI] else 0b0,
  ]
}

function legalize_medeleg(o : Medeleg, v : xlenbits) -> Medeleg = {
  /* M-EnvCalls delegation is not supported */
  [Mk_Medeleg(v) with MEnvCall = 0b0]
}

function legalize_mideleg(o : Minterrupts, v : xlenbits) -> Minterrupts = {
  /* M-mode interrupt delegation bits "should" be hardwired to 0. */
  /* FIXME: needs verification against eventual spec language. */
  [Mk_Minterrupts(v) with MEI = 0b0, MTI = 0b0, MSI = 0b0]
}

mapping clause csr_name_map = 0x304  <-> "mie"
mapping clause csr_name_map = 0x344  <-> "mip"
mapping clause csr_name_map = 0x302  <-> "medeleg"
mapping clause csr_name_map = 0x303  <-> "mideleg"

function clause is_CSR_defined(0x304) = true // mie
function clause is_CSR_defined(0x344) = true // mip
function clause is_CSR_defined(0x302) = extensionEnabled(Ext_S) // medeleg
function clause is_CSR_defined(0x303) = extensionEnabled(Ext_S) // mideleg

function clause read_CSR(0x304) = mie.bits
function clause read_CSR(0x344) = mip.bits
function clause read_CSR(0x302) = medeleg.bits
function clause read_CSR(0x303) = mideleg.bits

function clause write_CSR(0x304, value) = { mie = legalize_mie(mie, value); mie.bits }
function clause write_CSR(0x344, value) = { mip = legalize_mip(mip, value); mip.bits }
function clause write_CSR(0x302, value) = { medeleg = legalize_medeleg(medeleg, value); medeleg.bits }
function clause write_CSR(0x303, value) = { mideleg = legalize_mideleg(mideleg, value); mideleg.bits }

function lower_mip(m : Minterrupts, d : Minterrupts) -> Sinterrupts = {
  let s : Sinterrupts = Mk_Sinterrupts(zeros());

  [s with
    SEI = m[SEI] & d[SEI],
    STI = m[STI] & d[STI],
    SSI = m[SSI] & d[SSI],
  ]
}

/* Provides the sie read view of mie (m) as delegated by mideleg (d). */
function lower_mie(m : Minterrupts, d : Minterrupts) -> Sinterrupts = {
  let s : Sinterrupts = Mk_Sinterrupts(zeros());

  [s with
    SEI = m[SEI] & d[SEI],
    STI = m[STI] & d[STI],
    SSI = m[SSI] & d[SSI],
  ]
}

function lift_sip(o : Minterrupts, d : Minterrupts, s : Sinterrupts) -> Minterrupts = {
  let m : Minterrupts = o;
  let m = if d[SSI] == 0b1 then [m with SSI = s[SSI]] else m;
  m
}

function legalize_sip(m : Minterrupts, d : Minterrupts, v : xlenbits) -> Minterrupts = {
  lift_sip(m, d, Mk_Sinterrupts(v))
}

mapping clause csr_name_map = 0x144  <-> "sip"
function clause is_CSR_defined(0x144) = extensionEnabled(Ext_S) // sip
function clause read_CSR(0x144) = lower_mip(mip, mideleg).bits
function clause write_CSR(0x144, value) = { mip = legalize_sip(mip, mideleg, value); mip.bits }

mapping clause csr_name_map = 0x342  <-> "mcause"
function clause is_CSR_defined(0x342) = true // mcause
function clause read_CSR(0x342) = mcause.bits
function clause write_CSR(0x342, value) = { mcause.bits = value; mcause.bits }

function legalize_menvcfg(o : MEnvcfg, v : bits(64)) -> MEnvcfg = {
  let v = Mk_MEnvcfg(v);
  [o with
    FIOM = if sys_enable_writable_fiom() then v[FIOM] else 0b0,
    CBZE = if extensionEnabled(Ext_Zicboz) then v[CBZE] else 0b0,
    CBCFE = if extensionEnabled(Ext_Zicbom) then v[CBCFE] else 0b0,
    CBIE = if extensionEnabled(Ext_Zicbom) then (if v[CBIE] != 0b10 then v[CBIE] else 0b00) else 0b00,
    STCE = if extensionEnabled(Ext_Sstc) then v[STCE] else 0b0,
    // Other extensions are not implemented yet so all other fields are read only zero.
  ]
}

function legalize_senvcfg(o : SEnvcfg, v : xlenbits) -> SEnvcfg = {
  let v = Mk_SEnvcfg(v);
  [o with
    FIOM = if sys_enable_writable_fiom() then v[FIOM] else 0b0,
    CBZE = if extensionEnabled(Ext_Zicboz) then v[CBZE] else 0b0,
    CBCFE = if extensionEnabled(Ext_Zicbom) then v[CBCFE] else 0b0,
    CBIE = if extensionEnabled(Ext_Zicbom) then (if v[CBIE] != 0b10 then v[CBIE] else 0b00) else 0b00,
    // Other extensions are not implemented yet so all other fields are read only zero.
  ]
}

mapping clause csr_name_map = 0x30A  <-> "menvcfg"
mapping clause csr_name_map = 0x31A  <-> "menvcfgh"
mapping clause csr_name_map = 0x10A  <-> "senvcfg"

function clause is_CSR_defined(0x30A) = extensionEnabled(Ext_U) // menvcfg
function clause is_CSR_defined(0x31A) = extensionEnabled(Ext_U) & (xlen == 32) // menvcfgh
function clause is_CSR_defined(0x10A) = extensionEnabled(Ext_S) // senvcfg

function clause read_CSR(0x30A) = menvcfg.bits[xlen - 1 .. 0]
function clause read_CSR(0x31A if xlen == 32) = menvcfg.bits[63 .. 32]
function clause read_CSR(0x10A) = senvcfg.bits[xlen - 1 .. 0]

function clause write_CSR((0x30A, value) if xlen == 32) = { menvcfg = legalize_menvcfg(menvcfg, menvcfg.bits[63 .. 32] @ value); menvcfg.bits[31 .. 0] }
function clause write_CSR((0x30A, value) if xlen == 64) = { menvcfg = legalize_menvcfg(menvcfg, value); menvcfg.bits }
function clause write_CSR((0x31A, value) if xlen == 32) = { menvcfg = legalize_menvcfg(menvcfg, value @ menvcfg.bits[31 .. 0]); menvcfg.bits[63 .. 32] }
function clause write_CSR(0x10A, value) = { senvcfg = legalize_senvcfg(senvcfg, zero_extend(value)); senvcfg.bits[xlen - 1 .. 0] }

function legalize_satp32(a : Architecture, o : bits(32), v : bits(32)) -> bits(32) = {
  /* all 32-bit satp modes are valid */
  v
}

function legalize_satp64(a : Architecture, o : bits(64), v : bits(64)) -> bits(64) = {
  let s = Mk_Satp64(v);
  match satp64Mode_of_bits(a, s[Mode]) {
    None()     => o,
    Some(Sv32) => o,  /* Sv32 is unsupported for now */
    Some(_)    => s.bits
  }
}

function legalize_satp(a : Architecture,
                       o : xlenbits,        // previous value of satp
                       v : xlenbits)        // proposed new value of satp
                      -> xlenbits = {       // new legal value of satp
  if xlen == 32 then {
    // The slice and extend ops below are no-ops when xlen==32,
    // but appease the type-checker when xlen==64 (when this code is not executed!)
    let o32      : bits(32) = o[31 .. 0];
    let v32      : bits(32) = v[31 .. 0];
    let new_satp : bits(32) = legalize_satp32(a, o32, v32);
    zero_extend(new_satp);
  } else if xlen == 64 then {
    // The extend and truncate ops below are no-ops when xlen==64,
    // but appease the type-checker when xlen==32 (when this code is not executed!)
    let o64      : bits(64) = zero_extend(o);
    let v64      : bits(64) = zero_extend(v);
    let new_satp : bits(64) = legalize_satp64(a, o64, v64);
    truncate(new_satp, xlen)
  } else
    internal_error(__FILE__, __LINE__, "Unsupported xlen" ^ dec_str(xlen))
}

function legalize_misa(m : Misa, v : xlenbits) -> Misa = {
  let  v = Mk_Misa(v);
  /* Suppress updates to MISA if MISA is not writable or if by disabling C next PC would become misaligned or an extension vetoes */
  if   not(sys_enable_writable_misa()) | (v[C] == 0b0 & (nextPC[1] == bitone | ext_veto_disable_C()))
  then m
  else {
    /* Suppress enabling C if C was disabled at boot (i.e. not supported) */
    let m = if not(sys_enable_rvc()) then m else [m with C = v[C]];
    /* Suppress updates to misa.{f,d} if disabled at boot */
    if   not(sys_enable_fdext())
    then m
    else [m with F = v[F], D = v[D] & v[F]]
  }
}

mapping clause csr_name_map = 0x301  <-> "misa"
function clause is_CSR_defined(0x301) = true // misa
function clause read_CSR(0x301) = misa.bits
function clause write_CSR(0x301, value) = { misa = legalize_misa(misa, value); misa.bits }

function get_mstatus_SXL(m : Mstatus) -> arch_xlen = {
  if   xlen == 32
  then arch_to_bits(RV32)
  else m.bits[35 .. 34]
}

function set_mstatus_SXL(m : Mstatus, a : arch_xlen) -> Mstatus = {
  if   xlen == 32
  then m
  else {
    let m = vector_update_subrange(m.bits, 35, 34,  a);
    Mk_Mstatus(m)
  }
}

function get_mstatus_UXL(m : Mstatus) -> arch_xlen = {
  if   xlen == 32
  then arch_to_bits(RV32)
  else m.bits[33 .. 32]
}

function set_mstatus_UXL(m : Mstatus, a : arch_xlen) -> Mstatus = {
  if   xlen == 32
  then m
  else {
    let m = vector_update_subrange(m.bits, 33, 32,  a);
    Mk_Mstatus(m)
  }
}

function cur_Architecture() -> Architecture = {
  let a : arch_xlen =
    match (cur_privilege) {
      Machine    => misa[MXL],
      Supervisor => get_mstatus_SXL(mstatus),
      User       => get_mstatus_UXL(mstatus)
    };
  match architecture(a) {
    Some(a) => a,
    None()  => internal_error(__FILE__, __LINE__, "Invalid current architecture")
  }
}

mapping clause csr_name_map = 0x180  <-> "satp"
function clause is_CSR_defined(0x180) = extensionEnabled(Ext_S)
function clause read_CSR(0x180) = satp
function clause write_CSR(0x180, value) = { satp = legalize_satp(cur_Architecture(), satp, value); satp }

mapping clause csr_name_map = 0x343  <-> "mtval"
function clause is_CSR_defined(0x343) = true // mtval
function clause read_CSR(0x343) = mtval
function clause write_CSR(0x343, value) = { mtval = value; mtval }

function legalize_xepc(v : xlenbits) -> xlenbits = {
  // allow writing xepc[1] only if misa.C is enabled or could be enabled.
  if   sys_enable_rvc()
  then [v with 0 = bitzero]
  else [v with 1..0 = zeros()]
}

function align_pc(addr : xlenbits) -> xlenbits = {
  if misa[C] == 0b1
  then [addr with 0 = bitzero]
  else [addr with 1..0 = zeros()]
}

val get_xepc : Privilege -> xlenbits
function get_xepc(p) =
  match p {
    Machine    => align_pc(mepc),
    Supervisor => align_pc(sepc),
    User       => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
  }

val set_xepc : (Privilege, xlenbits) -> xlenbits
function set_xepc(p, value) = {
  let target = legalize_xepc(value);
  match p {
    Machine    => mepc = target,
    Supervisor => sepc = target,
    User       => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
  };
  target
}

function legalize_tvec(o : Mtvec, v : xlenbits) -> Mtvec = {
 let v = Mk_Mtvec(v);
 match (trapVectorMode_of_bits(v[Mode])) {
   TV_Direct => v,
   TV_Vector => v,
   _         => [v with Mode = o[Mode]]
 }
}

function get_mtvec() -> xlenbits =
  mtvec.bits

function get_stvec() -> xlenbits =
  stvec.bits

function set_mtvec(value : xlenbits) -> xlenbits = {
  mtvec = legalize_tvec(mtvec, value);
  mtvec.bits
}

function set_stvec(value : xlenbits) -> xlenbits = {
  stvec = legalize_tvec(stvec, value);
  stvec.bits
}

mapping clause csr_name_map = 0x105  <-> "stvec"
mapping clause csr_name_map = 0x141  <-> "sepc"
mapping clause csr_name_map = 0x305  <-> "mtvec"
mapping clause csr_name_map = 0x341  <-> "mepc"

function clause is_CSR_defined(0x105) = extensionEnabled(Ext_S) // stvec
function clause is_CSR_defined(0x141) = extensionEnabled(Ext_S) // sepc
function clause is_CSR_defined(0x305) = true // mtvec
function clause is_CSR_defined(0x341) = true // mepc

function clause read_CSR(0x105) = get_stvec()
function clause read_CSR(0x141) = get_xepc(Supervisor)
function clause read_CSR(0x305) = get_mtvec()
function clause read_CSR(0x341) = get_xepc(Machine)

function clause write_CSR(0x105, value) = { set_stvec(value) }
function clause write_CSR(0x141, value) = { set_xepc(Supervisor, value) }
function clause write_CSR(0x305, value) = { set_mtvec(value) }
function clause write_CSR(0x341, value) = { set_xepc(Machine, value) }

mapping clause csr_name_map = 0x142  <-> "scause"
mapping clause csr_name_map = 0x143  <-> "stval"

function clause is_CSR_defined(0x142) = extensionEnabled(Ext_S) // scause
function clause is_CSR_defined(0x143) = extensionEnabled(Ext_S) // stval

function clause read_CSR(0x142) = scause.bits
function clause read_CSR(0x143) = stval

function clause write_CSR(0x142, value) = { scause.bits = value; scause.bits }
function clause write_CSR(0x143, value) = { stval = value; stval }
