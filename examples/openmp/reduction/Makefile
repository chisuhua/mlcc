#-----------------------------------------------------------------------
#
#  Makefile: Cuda clang demo Makefile for both amdgcn and nvptx targets.
#            amdgcn GPU targets begin with "gfx". nvptx targets begin
#            with sm_.  Example: To build and run on k4000 do this:
#
#            export HCC2_GPU=sm_30
#            make run
#
#  Run "make help" to see other options for this Makefile

TESTNAME = reduction
TESTSRC  = reduction.c

HCC2           ?= /opt/rocm/hcc2
HCC2_GPU       ?= gfx803   # Default HCC2_GPU is gfx803 which is fiji
HCC2_CPUTARGET ?= x86_64-pc-linux-gnu
CC              = $(HCC2)/bin/clang

ifeq (sm_,$(findstring sm_,$(HCC2_GPU)))
  HCC2_GPUTARGET = nvptx64-nvidia-cuda
else
  HCC2_GPUTARGET = amdgcn-amd-amdhsa
endif

# Sorry, clang openmp requires these complex options
CFLAGS = -O3 -target $(HCC2_CPUTARGET) -fopenmp -fopenmp-targets=$(HCC2_GPUTARGET) -Xopenmp-target=$(HCC2_GPUTARGET) -march=$(HCC2_GPU)

ifeq ($(OFFLOAD_DEBUG),1)
  $(info    DEBUG Mode ON)
  CCENV  = env LIBRARY_PATH=$(HCC2)/lib-debug
  RUNENV = LIBOMPTARGET_DEBUG=1
endif

ifeq ($(VERBOSE),1)
  $(info    Compilation VERBOSE Mode ON)
  CFLAGS += -v
endif

ifeq ($(TEMPS),1)
  $(info    Compilation and linking save-temp Mode ON)
  CFLAGS += -save-temps -fopenmp-dump-offload-linker-script
endif

ifeq (sm_,$(findstring sm_,$(HCC2_GPU)))
  CUDA   ?= /usr/local/cuda
  UNAMEP = $(shell uname -p)
  LFLAGS += -L$(CUDA)/targets/$(UNAMEP)-linux/lib -lcudart
endif

CFLAGS += $(EXTRA_CFLAGS)

# ----- Demo compile and link in one step, no object code saved
$(TESTNAME): $(TESTSRC)
	$(CCENV) $(CC) $(CFLAGS) $(LFLAGS) $^ -o $@

run: $(TESTNAME)
	$(RUNENV) ./$(TESTNAME)

#  ----   Demo compile and link in two steps, object saved
$(TESTNAME).o: $(TESTSRC)
	$(CCENV) $(CC) -c $(CFLAGS) $^ -o $@

obin:	$(TESTNAME).o
	$(CCENV) $(CC) $(CFLAGS) $(LFLAGS) $^ -o $@

run_obin: obin
	$(RUNENV) ./obin

help:
	@echo
	@echo "Source[s]:		$(TESTSRC)"
	@echo "Application binary:    	$(TESTNAME)"
	@echo "Target GPU:		$(HCC2_GPU)"
	@echo "Target triple:		$(HCC2_GPUTARGET)"
	@echo "HCC2 compiler: 		$(CC)"
	@echo "Compile flags:		$(CFLAGS)"
ifeq (sm_,$(findstring sm_,$(HCC2_GPU)))
	@echo "CUDA installation:	$(CUDA)"
endif
	@echo
	@echo "This Makefile supports these targets:"
	@echo
	@echo " make			// Builds $(TESTNAME) "
	@echo " make run		// Executes $(TESTNAME) "
	@echo
	@echo " make $(TESTNAME).o		// build object file "
	@echo " make obin		// Link object file to build binary "
	@echo " make run_obin		// Execute obin "
	@echo
	@echo " make clean"
	@echo " make help"
	@echo
	@echo "Environment variables used by this Makefile:"
	@echo "  HCC2_GPU=<GPU>       Target GPU, e.g sm_30, default=gfx803. To build for"
	@echo "                       Nvidia GPUs, set HCC2_GPU=sm_60 or appropriate sm_"
	@echo "  HCC2=<dir>           HCC2 install dir, default=/opt/rocm/hcc2"
	@echo "  EXTRA_CFLAGS=<args>  extra arguments for compiler"
	@echo "  OFFLOAD_DEBUG=n      if n=1, compile and run in Debug mode"
	@echo "  VERBOSE=n            if n=1, add verbose output"
	@echo "  TEMPS=1              do not delete intermediate files"
ifeq (sm_,$(findstring sm_,$(HCC2_GPU)))
	@echo "  CUDA=<dir>           CUDA install dir, default=/usr/local/cuda"
endif
	@echo

# Cleanup anything this makefile can create
clean:
	rm -f $(TESTNAME) obin *.i *.ii *.bc *.lk a.out-* *.ll *.s *.o *.cubin
