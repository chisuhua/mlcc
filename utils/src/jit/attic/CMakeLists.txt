cmake_minimum_required(VERSION 2.8)

###################################################################################
set(PROJ isa_llvm)
set(PROJ1 llvm_base_lib)
project(${PROJ})

#set(CMAKE_BUILD_TYPE Release)
set(CMAKE_BUILD_TYPE Debug)
#set(CMAKE_VERBOSE_MAKEFILE true)

include(${PROJECT_ROOT_PATH}/cmake/configure.cmake)

add_definitions(-DDLL_EXPORT_kernel)
add_definitions(-DDEBUG)

include_directories(${LLVM_INCLUDE_DIRS})

add_definitions(${LLVM_DEFINITIONS})


llvm_map_components_to_libnames(LIBS
  CodeGen
  Core
  ExecutionEngine
  IRReader
  Interpreter
  MC
  MCJIT
  Object
  OrcJIT
  RuntimeDyld
  SelectionDAG
  Target
  TransformUtils
  X86CodeGen
  X86AsmParser
  X86AsmPrinter
  X86Desc
  X86Disassembler
  X86Info
  X86Utils
  AsmParser
  ExecutionEngine
  RuntimeDyld
  SelectionDAG
  AsmPrinter
  GlobalISel
  CodeGen
  BitWriter
  ScalarOpts
  AggressiveInstCombine
  InstCombine
  Target
  TransformUtils
  Analysis
  ProfileData
  Object
  BitReader
  X86AsmPrinter
  X86Utils
  Core
  MCParser
  MCDisassembler
  MC
  BinaryFormat
  DebugInfoCodeView
  DebugInfoMSF
  Demangle
  Support
)

file(GLOB rootfunc
        root_func.cpp
	)


add_library(${PROJ} SHARED ${rootfunc})
add_library(${PROJ1} SHARED IsaExecutor.cpp )
#add_library(${PROJ} STATIC ${rootfunc})
set_target_properties(${PROJ} PROPERTIES OUTPUT_NAME ${PROJ})
target_link_libraries(${PROJ1}
    ${LIBS}
	)
#
# set_target_properties(${PROJ}_rootfunc PROPERTIES LINKER_LANGUAGE C)
