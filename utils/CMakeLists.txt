##===----------------------------------------------------------------------===##
#
#                     The LLVM Compiler Infrastructure
#
# This file is dual licensed under the MIT and the University of Illinois Open
# Source Licenses. See LICENSE.txt for details.
##===----------------------------------------------------------------------===##
#
# utils/CMakeLists.txt
# Written by Greg Rodgers (Gregory.Rodgers@amd.com)
#
##===----------------------------------------------------------------------===##

cmake_minimum_required(VERSION 2.8 FATAL_ERROR)
if ("${CMAKE_SOURCE_DIR}" STREQUAL "${CMAKE_CURRENT_SOURCE_DIR}")
  project(mlccutils)
endif()
add_custom_target(mlccutils ALL)

find_package(LLVM QUIET CONFIG
  PATHS
  $ENV{MLCC}
  NO_DEFAULT_PATH
)

if (LLVM_DIR)
  if("{CMAKE_INSTALL_PREFIX}" STREQUAL "")
     set(CMAKE_INSTALL_PREFIX ${LLVM_INSTALL_PREFIX})
  endif()
  message("")
  message(STATUS "MLCC LLVM Found!")
  message(STATUS "     LLVM_PACKAGE_VERSION:     ${LLVM_PACKAGE_VERSION} ")
  message(STATUS "     LLVM_DIR:                 ${LLVM_DIR}")
  message(STATUS "     LLVM LLVM_INSTALL_PREFIX: ${LLVM_INSTALL_PREFIX}")
  message(STATUS "     CMAKE_INSTALL_PREFIX:     ${CMAKE_INSTALL_PREFIX}")
  message("")
else()
  message("")
  message("  ERROR:  Could not find an MLCC version of LLVM.")
  message("          You must build MLCC before building MLCC utils")
  message("")
  error(" Could not find an mlcc version of LLVM.")
endif()


set(MLCC_DIR_FOUND ${LLVM_DIR})
set(MLCC_INSTALL_PREFIX ${LLVM_INSTALL_PREFIX})
set(MLCC_MAIN_INCDIR ${LLVM_BUILD_MAIN_INCLUDE_DIR})
set(MLCC_BINDIR ${MLCC_INSTALL_PREFIX}/bin)
set(MLCC_INCDIR ${MLCC_INSTALL_PREFIX}/include)
set(MLCC_LIBDIR ${MLCC_INSTALL_PREFIX}/lib)
set(MLCC_LIBS
  ${MLCC_LIBDIR}/libLLVMBitWriter.a
  ${MLCC_LIBDIR}/libLLVMBitReader.a
  ${MLCC_LIBDIR}/libLLVMObject.a
  ${MLCC_LIBDIR}/libLLVMCore.a
  ${MLCC_LIBDIR}/libLLVMDemangle.a
  ${MLCC_LIBDIR}/libLLVMMC.a
  ${MLCC_LIBDIR}/libLLVMMCParser.a
  ${MLCC_LIBDIR}/libLLVMSupport.a
  ${MLCC_LIBDIR}/libLLVMBinaryFormat.a )
mark_as_advanced(
  MLCC_DIR_FOUND
  MLCC_INSTALL_PREFIX
  MLCC_BINDIR
  MLCC_INCDIR
  MLCC_LIBDIR
  MLCC_MAIN_INCDIR)

execute_process(COMMAND $ENV{MLCC}/bin/llvm-config --includedir
	OUTPUT_VARIABLE LLVM_SRC_INCLUDE
	)
if (LLVM_SRC_INCLUDE)
  message("")
  message(STATUS "     LLVM LLVM_SRC_INCLUDE: ${LLVM_SRC_INCLUDE}")
  message("")
else()
  message("")
  message("  ERROR:  Could not find an MLCC version of LLVM.")
  message("")
  error(" Could not find include dir from llvm-config --includedir.")
endif()
include_directories(${LLVM_SRC_INCLUDE})

string(LENGTH ${LLVM_PACKAGE_VERSION} vlen)
math(EXPR vstart "${vlen}-5")
string(SUBSTRING ${LLVM_PACKAGE_VERSION} ${vstart} 5 version_str)

#FIXME:  This could be a loop
add_custom_command( OUTPUT mlcc
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/mlcc ${CMAKE_CURRENT_BINARY_DIR}/mlcc
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/mlcc)
add_custom_command( OUTPUT mlcc.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/mlcc > mlcc.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/mlcc)

add_custom_command( OUTPUT genco
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/genco ${CMAKE_CURRENT_BINARY_DIR}/genco
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/genco)
add_custom_command( OUTPUT genco.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/genco > genco.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/genco)

add_custom_command( OUTPUT cloc.sh
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/cloc.sh ${CMAKE_CURRENT_BINARY_DIR}/cloc.sh
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/cloc.sh)
# edit in place to preserve permissions
add_custom_command( OUTPUT cloc.sh.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/cloc.sh > cloc.sh.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/cloc.sh)

add_custom_command( OUTPUT mymcpu
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/mymcpu ${CMAKE_CURRENT_BINARY_DIR}/mymcpu
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/mymcpu)
add_custom_command( OUTPUT mymcpu.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/mymcpu > mymcpu.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/mymcpu)

add_custom_command( OUTPUT mlccversion
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/mlccversion ${CMAKE_CURRENT_BINARY_DIR}/mlccversion
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/mlccversion)
add_custom_command( OUTPUT mlccversion.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/mlccversion > mlccversion.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/mlccversion)

add_custom_command( OUTPUT clang-ocl
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/clang-ocl ${CMAKE_CURRENT_BINARY_DIR}/clang-ocl
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/clang-ocl)
add_custom_command( OUTPUT clang-ocl.phantom
   COMMAND /bin/sed -i -e "s/X\\.Y\\-Z/${version_str}/" ${CMAKE_CURRENT_BINARY_DIR}/clang-ocl > clang-ocl.phantom
   DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/clang-ocl)

# mymcpu reads the codename by searching for pciid from this generated gputable.
add_custom_command( OUTPUT gputable.txt
   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/gputable.txt ${CMAKE_CURRENT_BINARY_DIR}/gputable.txt
   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/gputable.txt)

#add_custom_command( OUTPUT change_llvm_target.py
#   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/change_llvm_target.py ${CMAKE_CURRENT_BINARY_DIR}/change_llvm_target.py
#   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/change_llvm_target.py)

#add_custom_command( OUTPUT fix_meta_yaml.py
#   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_meta_yaml.py ${CMAKE_CURRENT_BINARY_DIR}/fix_meta_yaml.py
#   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_meta_yaml.py)

#add_custom_command( OUTPUT fix_wrapper_kernel.py
#   COMMAND /bin/cp -p ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_wrapper_kernel.py ${CMAKE_CURRENT_BINARY_DIR}/fix_wrapper_kernel.py
#   DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_wrapper_kernel.py)

add_custom_target(utils_scripts ALL DEPENDS bin/change_llvm_target.py bin/fix_meta_yaml.py bin/fix_wrapper_kernel.py mlcc.phantom genco.phantom cloc.sh.phantom mymcpu.phantom mlccversion.phantom clang-ocl.phantom gputable.txt)

# We need prepare-builtins in the mlcc distribution to build bc libs for components
list(APPEND CMAKE_MODULE_PATH ${LLVM_CMAKE_DIR})
include(AddLLVM)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -fno-rtti")
add_definitions(${LLVM_DEFINITIONS})
include_directories(${LLVM_INCLUDE_DIR})
add_executable(prepare-builtins ${CMAKE_CURRENT_SOURCE_DIR}/src/prepare-builtins.cpp)
llvm_map_components_to_libnames(llvm_libs support core bitreader bitwriter)
target_link_libraries(prepare-builtins ${llvm_libs})

# ppu_co_writer which is write out kernel in ppu codeobject format
add_executable(ppu_co_writer ${CMAKE_CURRENT_SOURCE_DIR}/src/ppu_co_writer.cpp)
target_include_directories(ppu_co_writer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external)
target_include_directories(ppu_co_writer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external/yaml-cpp/include)
target_include_directories(ppu_co_writer PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/external/msgpack-c/include)
target_link_libraries(ppu_co_writer yaml-cpp)

install(PROGRAMS
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/bundle.sh
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/unbundle.sh
   ${CMAKE_CURRENT_BINARY_DIR}/mlcc
   ${CMAKE_CURRENT_BINARY_DIR}/genco
   ${CMAKE_CURRENT_BINARY_DIR}/cloc.sh
   ${CMAKE_CURRENT_BINARY_DIR}/mymcpu
   ${CMAKE_CURRENT_BINARY_DIR}/gputable.txt
   ${CMAKE_CURRENT_BINARY_DIR}/mlccversion
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/mygpu
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/clang-ocl
   ${CMAKE_CURRENT_BINARY_DIR}/prepare-builtins
   ${CMAKE_CURRENT_BINARY_DIR}/ppu_co_writer
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/change_llvm_target.py
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_meta_yaml.py
   ${CMAKE_CURRENT_SOURCE_DIR}/bin/fix_wrapper_kernel.py
   DESTINATION "bin")

#option(YAML_CPP_BUILD_TESTS OFF)
#option(YAML_CPP_BUILD_TOOLS  OFF)
#option(YAML_CPP_BUILD_CONTRIB OFF)
#option(YAML_CPP_INSTALL OFF)


add_subdirectory(external/yaml-cpp)
