include ../Makefile.defs

TESTNAME        = math_sqrt_float
TESTSRC_MAIN    = math_sqrt_float.c
TESTSRC_AUX     =
TESTSRC_ALL     = $(TESTSRC_MAIN) $(TESTSRC_AUX)

CLANG           = clang
OMP_BIN         = $(HCC2)/bin/$(CLANG)
CC              = $(OMP_BIN) $(VERBOSE)
EXTRA_CFLAGS    =
EXTRA_LDFLAGS   = -lm
EXTRA_OMP_FLAGS =

include ../Makefile.rules
