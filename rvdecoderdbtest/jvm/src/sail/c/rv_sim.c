#include "./lib.h"
#include "sail_coverage.h"
#include "sail.h"

int main(int argc, char **argv) {
  model_init();
  zinit(UNIT);
  zstep(UNIT);
}