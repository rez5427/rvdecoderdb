function findPendingInterrupt(ip : xlenbits) -> option(InterruptType) = {
  let ip = Mk_MIP(ip);
  if      ip[MEIP] == 0b1 then Some(I_M_External)
  else if ip[MSIP] == 0b1 then Some(I_M_Software)
  else if ip[MTIP] == 0b1 then Some(I_M_Timer)
  else if ip[SEIP] == 0b1 then Some(I_S_External)
  else if ip[SSIP] == 0b1 then Some(I_S_Software)
  else if ip[STIP] == 0b1 then Some(I_S_Timer)
  else                        None()
}

function getPendingSet(priv : Privilege) -> option((xlenbits, Privilege)) = {
  // mideleg can only be non-zero if we support Supervisor mode.
  assert(extensionEnabled(Ext_S) | mideleg.bits == zeros());

  let pending_m = mip.bits & mie.bits & ~(mideleg.bits);
  let pending_s = mip.bits & mie.bits & mideleg.bits;

  let mIE = (priv == Machine    & mstatus[MIE] == 0b1) | priv == Supervisor | priv == User;
  let sIE = (priv == Supervisor & mstatus[SIE] == 0b1) | priv == User;

  if      mIE & (pending_m != zeros()) then Some((pending_m, Machine))
  else if sIE & (pending_s != zeros()) then Some((pending_s, Supervisor))
  else None()
}


function dispatchInterrupt(priv : Privilege) -> option((InterruptType, Privilege)) = {
  match getPendingSet(priv) {
    None()       => None(),
    Some(ip, p)  => match findPendingInterrupt(ip) {
                      None()  => None(),
                      Some(i) => Some((i, p)),
                    }
  }
}

function tval(excinfo : option(xlenbits)) -> xlenbits = {
  match (excinfo) {
    Some(e) => e,
    None()  => zeros()
  }
}

function tvec_addr(m : MTVEC, c : MCAUSE) -> option(xlenbits) = {
  let base : xlenbits = m[Base] @ 0b00;
  match (trapVectorMode_of_bits(m[Mode])) {
    TV_Direct => Some(base),
    TV_Vector => if   c[IsInterrupt] == 0b1
                 then Some(base + (zero_extend(c[Cause]) << 2))
                 else Some(base),
    TV_Reserved => None()
  }
}

function handle_trap_extension(p : Privilege, pc : xlenbits, u : option(unit)) -> unit = ()

function prepare_trap_vector(p : Privilege) -> xlenbits = {
  match p {
    Machine => {
      match (trapVectorMode_of_bits(mtvec[Mode])) {
        TV_Direct => mtvec[Base] @ 0b00,
        TV_Vector => if   mcause[IsInterrupt] == 0b1
                     then (mtvec[Base] @ 0b00) + (zero_extend(mcause[Cause]) << 2)
                     else (mtvec[Base] @ 0b00),
        TV_Reserved => internal_error(__FILE__, __LINE__, "Invalid tvec mode")
      }
    },
    Supervisor => {
      match (trapVectorMode_of_bits(stvec[Mode])) {
        TV_Direct => stvec[Base] @ 0b00,
        TV_Vector => if   scause[IsInterrupt] == 0b1
                     then (stvec[Base] @ 0b00) + (zero_extend(scause[Cause]) << 2)
                     else (stvec[Base] @ 0b00),
        TV_Reserved => internal_error(__FILE__, __LINE__, "Invalid tvec mode")
      }
    },
    User => internal_error(__FILE__, __LINE__, "Invalid privilege level")
  }
}

function trap_handler(del_priv : Privilege, intr : bool, c : exc_code, pc : xlenbits, info : option(xlenbits), ext : option(ext_exception))
                     -> xlenbits = {
  print_platform("handling " ^ (if intr then "int#" else "exc#")
                      ^ BitStr(c) ^ " at priv " ^ to_str(del_priv)
                      ^ " with tval " ^ BitStr(tval(info)));

  match (del_priv) {
    Machine => {
       mcause[IsInterrupt] = bool_to_bits(intr);
       mcause[Cause]       = zero_extend(c);

       mstatus[MPIE] = mstatus[MIE];
       mstatus[MIE]  = 0b0;
       mstatus[MPP]  = privLevel_to_bits(cur_privilege);
       mtval.bits           = tval(info);
       mepc.bits            = pc;

       cur_privilege   = del_priv;

       handle_trap_extension(del_priv, pc, ext);

       print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));

       prepare_trap_vector(del_priv)
    },
    Supervisor => {
       assert (extensionEnabled(Ext_S), "no supervisor mode present for delegation");

       scause[IsInterrupt] = bool_to_bits(intr);
       scause[Cause]       = zero_extend(c);

       mstatus[SPIE] = mstatus[SIE];
       mstatus[SIE]  = 0b0;
       mstatus[SPP]  = match cur_privilege {
                           User => 0b0,
                           Supervisor => 0b1,
                           Machine => internal_error(__FILE__, __LINE__, "invalid privilege for s-mode trap")
                         };
       stval.bits           = tval(info);
       sepc.bits            = pc;

       cur_privilege   = del_priv;

       handle_trap_extension(del_priv, pc, ext);

       print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));

       prepare_trap_vector(del_priv)
    },
    User => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
  };
}

function handle_interrupt(i : InterruptType, del_priv : Privilege) -> unit =
  set_next_pc(trap_handler(del_priv, true, interruptType_to_bits(i), PC, None(), None()))

newtype virtaddr = virtaddr : xlenbits
function virtaddr_bits(virtaddr(vaddr) : virtaddr) -> xlenbits = vaddr

struct sync_exception = {
  trap    : ExceptionType,
  excinfo : option(xlenbits),
  ext     : option(ext_exception)   /* for extensions */
}

union ctl_result = {
  CTL_TRAP : sync_exception,
  CTL_SRET : unit,
  CTL_MRET : unit,
}

function exception_delegatee(e : ExceptionType, p : Privilege) -> Privilege = {
  let idx   = num_of_ExceptionType(e);
  let super = bit_to_bool(medeleg.bits[idx]);
  let deleg = if extensionEnabled(Ext_S) & super then Supervisor else Machine;
  /* We cannot transition to a less-privileged mode. */
  if   privLevel_to_bits(deleg) <_u privLevel_to_bits(p)
  then p else deleg
}

function align_pc(addr : xlenbits) -> xlenbits = {
  if misa[C] == 0b1
  then [addr with 0 = bitzero]
  else [addr with 1..0 = zeros()]
}

val get_xepc : Privilege -> xlenbits
function get_xepc(p) =
  match p {
    Machine    => align_pc(mepc.bits),
    Supervisor => align_pc(sepc.bits),
    User       => internal_error(__FILE__, __LINE__, "Invalid privilege level"),
  }

val prepare_xret_target : (Privilege) -> xlenbits
function prepare_xret_target(p) =
  get_xepc(p)

function exception_handler(cur_priv : Privilege, ctl : ctl_result,
                           pc: xlenbits) -> xlenbits = {
  match (cur_priv, ctl) {
    (_, CTL_TRAP(e)) => {
      let del_priv = exception_delegatee(e.trap, cur_priv);
      print_platform("trapping from " ^ to_str(cur_priv) ^ " to " ^ to_str(del_priv)
                          ^ " to handle " ^ to_str(e.trap));
      trap_handler(del_priv, false, exceptionType_to_bits(e.trap), pc, e.excinfo, e.ext)
    },
    (_, CTL_MRET())  => {
      let prev_priv   = cur_privilege;
      mstatus[MIE]  = mstatus[MPIE];
      mstatus[MPIE] = 0b1;
      cur_privilege   = privLevel_of_bits(mstatus[MPP]);
      mstatus[MPP]  = privLevel_to_bits(if extensionEnabled(Ext_U) then User else Machine);
      if   cur_privilege != Machine
      then mstatus[MPRV] = 0b0;

      print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));
      print_platform("ret-ing from " ^ to_str(prev_priv) ^ " to " ^ to_str(cur_privilege));

      prepare_xret_target(Machine)
    },
    (_, CTL_SRET())  => {
      let prev_priv   = cur_privilege;
      mstatus[SIE]  = mstatus[SPIE];
      mstatus[SPIE] = 0b1;
      cur_privilege   = if mstatus[SPP] == 0b1 then Supervisor else User;
      mstatus[SPP]  = 0b0;
      if   cur_privilege != Machine
      then mstatus[MPRV] = 0b0;

      print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits));
      print_platform("ret-ing from " ^ to_str(prev_priv)
                          ^ " to " ^ to_str(cur_privilege));

      prepare_xret_target(Supervisor)
    },
  }
}

function handle_mem_exception(virtaddr(addr) : virtaddr, e : ExceptionType) -> unit = {
  let t : sync_exception = struct { trap    = e,
                                    excinfo = Some(addr),
                                    ext     = None() } in
  set_next_pc(exception_handler(cur_privilege, CTL_TRAP(t), PC))
}
