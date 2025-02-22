val inst_fetch = pure "inst_fetch" : xlenbits -> bits(32)
val get_mip = pure "get_mip" : unit -> bits(64)
val get_sip = pure "get_sip" : unit -> bits(64)

function init() : unit -> unit = {
  init_base_regs();
  PC = zero_extend(0x80000000);
}

function step(unit) : unit -> unit = {
  mip = legalize_mip(mip, get_mip());
  mip = legalize_sip(mip, mideleg, get_sip());

  match dispatchInterrupt(cur_privilege) {
    Some(intr, priv) => {
      handle_interrupt(intr, priv);
    },
    None() => {
      let inst = inst_fetch(PC);
      if (inst[1 .. 0] != 0b11) then {
        let ast = ext_decode_compressed(inst[15 .. 0]);
        print_instr(assembly(ast));
        nextPC = PC + 2;
        execute(ast);
      } else {
        let ast = ext_decode(inst);
        print_instr(assembly(ast));
        nextPC = PC + 4;
        execute(ast);
      };
    }
  };

  PC = nextPC;
}

function main() : unit -> unit = {
  init();
  step();
}
