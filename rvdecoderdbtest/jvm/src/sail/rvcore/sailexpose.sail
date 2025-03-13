function init() : unit -> unit = {
  init_base_regs();
  PC = zero_extend(0x80000000);
}

function step(unit) : unit -> unit = {
  let inst = inst_fetch(PC);
  if (inst[1 .. 0] != 0b11) then {
    //let ast = ext_decode_compressed(inst[15 .. 0]);
    //print_instr(assembly(ast));
    nextPC = PC + 2;
    //execute(ast);
  } else {
    let ast = ext_decode(inst);
    nextPC = PC + 4;
    execute(ast);
  };

  PC = nextPC;
}

function main() : unit -> unit = {
  init();
  step();
}
