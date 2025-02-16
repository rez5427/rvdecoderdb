#pragma once
#include "sail.h"

typedef int unit;
#define UNIT 0
typedef uint64_t mach_bits;

unit print_instr(sail_string s);

unit zinit(unit);
unit zstep(unit);

mach_bits inst_fetch(mach_bits pc);