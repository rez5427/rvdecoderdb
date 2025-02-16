#include "sail.h"

#include <stdint.h>
#include <stdio.h>

unit print_instr(sail_string s)
{
  printf("%s\n", s);
  return UNIT;
}

mach_bits inst_fetch(mach_bits pc) {
  printf("inst_fetch: pc = %lx\n", pc);
  return UINT64_C(0x00c0006f);
}