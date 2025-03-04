#include "sail.h"

#include <stdint.h>
#include <stdio.h>

unit print_instr(sail_string s)
{
  printf("%s\n", s);
  return UNIT;
}

unit print_platform(sail_string s)
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

uint64_t readmem(uint64_t virtaddress, uint64_t rd_val, uint64_t satp) {
  printf("read_mem: virtaddress = %lx, rd_val = %lx, satp = %lx\n", virtaddress, rd_val, satp);
  return UINT64_C(0x0000000000000000);
}

unit writemem(uint64_t virtaddress, uint64_t data, uint64_t bytes, uint64_t satp) {
  printf("write_mem: address = %lx, data = %lx, bytes = %lx, satp = %lx\n", virtaddress, data, bytes, satp);
}

bool exception_raised(unit) {
  return false;
}

uint64_t get_exception(unit) {
  return 0x0000;
}

uint64_t get_mip(unit) {
  return 0x0000;
}

uint64_t get_sip(unit) {
  return 0x0000;
}