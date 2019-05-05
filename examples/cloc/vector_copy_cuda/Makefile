
TEST_NAME=vector_copy
CU_FILE=vector_copy

ifeq ($(HCC2),)
  HCC2 = /opt/rocm/hcc2
else
  $(info HCC2 environment variable using $(HCC2))
endif

#LFLAGS= -g  -Wl,--unresolved-symbols=ignore-in-shared-libs
LFLAGS = 
CFLAGS =  -std=c++11
FUNOPTS = -vv -ll
FUNOPTS = 

CXX_FILES := $(wildcard *.cpp)
OBJ_FILES := $(addprefix obj/, $(notdir $(CXX_FILES:.cpp=.o)))

all: $(TEST_NAME) $(CU_FILE).hsaco

$(TEST_NAME): $(OBJ_FILES) $(COMMON_OBJ_FILES)
	$(CXX) $(LFLAGS) $(OBJ_FILES) -L/opt/rocm/lib -lhsa-runtime64 -o $(TEST_NAME)

$(CU_FILE).hsaco :
	$(HCC2)/bin/cloc.sh $(FUNOPTS)  $(CU_FILE).cu

obj/%.o: %.cpp
	mkdir -p obj
	$(CXX) -I/opt/rocm/include -c $(CFLAGS) -o $@ $< 

clean:
	rm -rf obj/*o *.hsaco *.ll $(TEST_NAME)


test:	
	./$(TEST_NAME)


