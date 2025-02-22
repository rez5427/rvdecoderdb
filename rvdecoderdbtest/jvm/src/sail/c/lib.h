#pragma once
#include "sail.h"

typedef int unit;
#define UNIT 0
typedef uint64_t mach_bits;

// debug
unit print_instr(sail_string s);
unit print_reg(sail_string s);
unit print_platform(sail_string s);

// Inside sail
unit zinit(unit);
unit zstep(unit);
void model_init(void);

// need to implement
mach_bits inst_fetch(mach_bits pc);
uint64_t readmem(uint64_t address, uint64_t satp);
unit writemem(uint64_t address, uint64_t data, uint64_t bytes, uint64_t satp);
bool exception_raised(unit);
uint64_t get_exception(unit);
mach_bits get_mip(unit);
mach_bits get_sip(unit);