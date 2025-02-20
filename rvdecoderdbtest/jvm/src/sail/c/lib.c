#include "sail.h"

#include <stdint.h>
#include <stdio.h>

unit print_instr(sail_string s)
{
  printf("%s\n", s);
  return UNIT;
}

unit print_reg(sail_string s)
{
  printf("%s\n", s);
  return UNIT;
}

mach_bits inst_fetch(mach_bits pc) {
  printf("inst_fetch: pc = %lx\n", pc);
  return UINT64_C(0xFC3F2023);
}

uint64_t readmem(uint64_t address) {
  printf("read_mem: address = %lx\n", address);
  return UINT64_C(0x0000000000000000);
}

unit writemem(uint64_t address, uint64_t data,uint64_t bytes) {
  printf("write_mem: address = %lx, data = %lx, bytes = %lx\n", address, data, bytes);
}