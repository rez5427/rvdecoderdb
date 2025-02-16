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
	$(SAIL) $(SAIL_FLAGS) -O -Oconstant_fold -memo_z3 -c -c_include ./c/lib.h -c_no_main ./sail/prelude.sail ./sail/rv_xlen.sail ./sail/scattered.sail ./sail/rv_decode_ext.sail ./sail/reg.sail ./sail/rv_core.sail ./sail/expose.sail -o ./sail/rv_model

genSo:
	cc -g -shared -fPIC $(C_FLAGS) $(SAIL_LIB_DIR)/*.c $(C_LIBS) -o librv.so ./sail/rv_model.c

run:
	cc -g $(C_FLAGS) ./sail/rv_model.c $(C_SRCS) $(SAIL_LIB_DIR)/*.c $(C_LIBS) -o rv

.PHONY: generateC genSo run