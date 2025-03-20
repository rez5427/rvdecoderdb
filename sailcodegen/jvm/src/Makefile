SAIL_FLAGS += --require-version 0.18
SAIL_FLAGS += --strict-var
SAIL_FLAGS += -dno_cast

SAIL := sail

SAIL_DIR := $(shell $(SAIL) --dir)
SAIL_LIB_DIR := $(SAIL_DIR)/lib
SAIL_SRC_DIR := $(SAIL_DIR)/src

C_INCS = $(addprefix sail/c/, lib.h)
C_SRCS = $(addprefix sail/c/, lib.c rv_sim.c)

GMP_FLAGS = $(shell pkg-config --cflags gmp)
GMP_LIBS = $(shell pkg-config --libs gmp || echo -lgmp)

ZLIB_FLAGS = $(shell pkg-config --cflags zlib)
ZLIB_LIBS = $(shell pkg-config --libs zlib)

C_FLAGS = -I $(SAIL_LIB_DIR) -I sail/c $(GMP_FLAGS) $(ZLIB_FLAGS)
C_LIBS  = $(GMP_LIBS) $(ZLIB_LIBS)

generateC:
	$(SAIL) $(SAIL_FLAGS) -O -Oconstant_fold -memo_z3 -c -c_include ../c/lib.h -c_no_main ./sail/rvcore/lib/prelude.sail ./sail/rvcore/rv_xlen.sail ./sail/rvcore/capi.sail ./sail/rvcore/lib/scattered.sail ./sail/rvcore/arch/ArchPrelude.sail ./sail/rvcore/arch/ArchStatesPrivEnable.sail ./sail/rvcore/arch/ArchStateCsrBF.sail ./sail/rvcore/arch/ArchStates.sail ./sail/rvcore/arch/ArchStatesRW.sail ./sail/rvcore/arch/ArchStatesInit.sail ./sail/rvcore/rv_core.sail ./sail/rvcore/sailexpose.sail -o ./sail/rvcore/rv_model

clean:
	rm -f ./sail/rvcore/rv_model.c ./sail/rvcore/rv_core.sail ./sail/rvcore/rv_xlen.sail ./sail/rvcore/arch/ArchStateCsrBF.sail ./sail/rvcore/arch/ArchStatesRW.sail ./sail/rvcore/arch/ArchStatesPrivEnable.sail ./sail/rvcore/arch/ArchStates.sail ./z3_problems ./rv

run:
	cc -g $(C_FLAGS) ./sail/rvcore/rv_model.c $(C_SRCS) $(SAIL_LIB_DIR)/*.c $(C_LIBS) -o rv

.PHONY: generateC clean run