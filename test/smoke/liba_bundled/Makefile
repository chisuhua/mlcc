include ../Makefile.defs

TESTNAME        = liba_bundled
TESTSRC_MAIN    = main.c
TESTSRC_AUX     = MyDeviceLib/libMyDeviceLib.a
TESTSRC_ALL     = $(TESTSRC_MAIN) $(TESTSRC_AUX)

CLANG           = clang
OMP_BIN         = $(HCC2)/bin/$(CLANG)
CC              = $(OMP_BIN) $(VERBOSE)
EXTRA_CFLAGS    =
EXTRA_LDFLAGS   =
EXTRA_OMP_FLAGS =

ifeq (sm_,$(findstring sm_,$(DEVICE_ARCH)))
  GPUTYPE = nvptx
else
  GPUTYPE = amdgcn
endif

# Build the host and device libraries
MyDeviceLib/libMyDeviceLib.a : MyDeviceLib/Makefile MyDeviceLib/func_1v.c MyDeviceLib/func_2v.c MyDeviceLib/func_3v.c
	HCC2_GPU=$(DEVICE_ARCH) make -C MyDeviceLib libMyDeviceLib.a libMyDeviceLib-$(GPUTYPE)-$(DEVICE_ARCH).a

clean ::
	make -C MyDeviceLib clean

include ../Makefile.rules


