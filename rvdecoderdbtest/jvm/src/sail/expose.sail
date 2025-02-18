val inst_fetch = pure "inst_fetch" : xlenbits -> bits(32)

function init() : unit -> unit = {
  init_base_regs();
  PC = zero_extend(0x80000000);

}

function step(unit) : unit -> unit = {
  let ast = ext_decode(inst_fetch(PC));
  print_instr(assembly(ast));
  execute(ast);
  nextPC = PC + 4;
  PC = nextPC;
}

function main() : unit -> unit = {
  init();
  step();
}
