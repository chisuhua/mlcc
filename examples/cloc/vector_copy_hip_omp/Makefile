
TEST_NAME=vector_copy
CU_FILE=vector_copy

ifeq ($(HCC2),)
  HCC2 = /opt/rocm/hcc2
else
  $(info HCC2 environment variable using $(HCC2))
endif
HCC2_GPU       ?= gfx803   # Default HCC2_GPU is gfx803 which is fiji
HCC2_CPUTARGET ?= x86_64-pc-linux-gnu

ifeq (sm_,$(findstring sm_,$(HCC2_GPU)))
  HCC2_GPUTARGET = nvptx64-nvidia-cuda
else
  HCC2_GPUTARGET = amdgcn-amd-amdhsa
endif

#LFLAGS= -g  -Wl,--unresolved-symbols=ignore-in-shared-libs
LFLAGS = 
CFLAGS =  -std=c++11 -D__HIP_PLATFORM_HCC__ -O3 -target $(HCC2_CPUTARGET) -fopenmp -fopenmp-targets=$(HCC2_GPUTARGET) -Xopenmp-target=$(HCC2_GPUTARGET) -march=$(HCC2_GPU)
FUNOPTS = -vv -ll
FUNOPTS = 

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

CXX_FILES := $(wildcard *.cpp)
OBJ_FILES := $(addprefix obj/, $(notdir $(CXX_FILES:.cpp=.o)))

all: $(TEST_NAME) $(CU_FILE).hsaco

$(TEST_NAME): $(OBJ_FILES) $(COMMON_OBJ_FILES)
	$(CXX) $(OBJ_FILES) $(CFLAGS) -L/opt/rocm/lib -lhip_hcc -o $(TEST_NAME) $(LFLAGS)

$(CU_FILE).hsaco :
	$(HCC2)/bin/cloc.sh $(FUNOPTS)  $(CU_FILE).cu

obj/%.o: %.cpp
	mkdir -p obj
	$(CXX) -I/opt/rocm/include -c $(CFLAGS) -o $@ $< 

clean:
	rm -rf obj/*o *.hsaco *.ll $(TEST_NAME)


test:	
	./$(TEST_NAME)


