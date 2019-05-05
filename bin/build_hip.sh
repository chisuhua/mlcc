#!/bin/bash
#
#  File: build_hip.sh
#        Build the hip host and device runtimes, 
#        The install option will install components into the hcc2 installation. 
#        The components include:
#          hip headers installed in $HCC2/include/hip
#          hip host runtime installed in $HCC2/lib/libhiprt.so
#
# MIT License
#
# Copyright (c) 2017 Advanced Micro Devices, Inc. All Rights Reserved.
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#HCC2=${HCC2:-/opt/rocm/hcc2}
#HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
MLCC_REPOS=${MLCC_REPOS:-$THIS_SCRIPT_DIR/../..}

MLCC_BUILD_DIR=${MLCC_BUILD_DIR:-$MLCC_REPOS/build}
MLCC_BUILD_DIR_LLVM=$MLCC_BUILD_DIR/llvm

MLCC=${MLCC:-$MLCC_BUILD_DIR_LLVM}

#HIP_REPO_NAME=${HIP_REPO_NAME:-hip}
HIP_REPO_NAME=${HIP_REPO_NAME:-hip}
#HCC2_REPO_NAME=${HCC2_REPO_NAME:-hcc2}
#BUILD_HCC2=${BUILD_HCC2:-$HCC2_REPOS}
HIP_REPO_DIR=$MLCC_REPOS/$HIP_REPO_NAME


PROC=`uname -p`
if [ "$PROC" == "ppc64le" ] ||  [ "$PROC" == "aarch64" ] ; then
   export HIP_PLATFORM="none"
else
   export HIP_PLATFORM="hcc"
fi

# TODO shchi hack
export HIP_PLATFORM="clang"
export HIP_COMPILER="clang"

SUDO=${SUDO:-no}
if [ $SUDO == "set" ] ; then
   SUDO="sudo"
else
   SUDO=""
fi

#BUILD_DIR=${BUILD_HCC2}
BUILD_DIR=${MLCC_BUILD_DIR}

#BUILDTYPE="Release"
BUILDTYPE="Debug"

# Get the HCC2_VERSION_STRING from a file in this directory
#function getdname(){
#   local __DIRN=`dirname "$1"`
#   if [ "$__DIRN" = "." ] ; then
#      __DIRN=$PWD;
#   else
#      if [ ${__DIRN:0:1} != "/" ] ; then
#         if [ ${__DIRN:0:2} == ".." ] ; then
#               __DIRN=`dirname $PWD`/${__DIRN:3}
#         else
#            if [ ${__DIRN:0:1} = "." ] ; then
#               __DIRN=$PWD/${__DIRN:2}
#            else
#               __DIRN=$PWD/$__DIRN
#            fi
#         fi
#      fi
#   fi
#   echo $__DIRN
#}
#thisdir=$(getdname $0)
#[ ! -L "$0" ] || thisdir=$(getdname `readlink "$0"`)
#if [ -f $thisdir/MLCC_VERSION_STRING ] ; then

if [ -f $THIS_SCRIPT_DIR/MLCC_VERSION_STRING ] ; then
   MLCC_VERSION_STRING=`cat $THIS_SCRIPT_DIR/MLCC_VERSION_STRING`
else
   MLCC_VERSION_STRING=${MLCC_VERSION_STRING:-"0.5-2"}
fi
export MLCC_VERSION_STRING

INSTALL_DIR=${INSTALL_HIP:-"${MLCC}_${MLCC_VERSION_STRING}"}
LLVM_BUILD=$MLCC

REPO_BRANCH=${REPO_BRANCH:-HCC2.180805}
#  Check the repositories exist and are on the correct branch
function checkrepo(){
   cd $REPO_DIR
   COBRANCH=`git branch --list | grep "\*" | cut -d" " -f2`
   if [ "$COBRANCH" != "$REPO_BRANCH" ] ; then
      if [ "$COBRANCH" == "master" ] ; then 
        echo "EXIT:  Repository $REPO_DIR is on development branch: master"
        exit 1
      else 
        echo "ERROR:  The repository at $REPO_DIR is not on branch $REPO_BRANCH"
        echo "          It is on branch $COBRANCH"
        exit 1
     fi
   fi
   if [ ! -d $REPO_DIR ] ; then
      echo "ERROR:  Missing repository directory $REPO_DIR"
      exit 1
   fi
}
REPO_DIR=$MLCC_REPOS/$HIP_REPO_NAME
# TODO schi skip checkrepo
#checkrepo

if [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] ; then
  echo " "
  echo "Example commands and actions: "
  echo "  ./build_hip.sh                   cmake, make, NO Install "
  echo "  ./build_hip.sh nocmake           NO cmake, make,  NO install "
  echo "  ./build_hip.sh install           NO Cmake, make install "
  echo " "
  exit
fi

if [ ! -d $HIP_REPO_DIR ] ; then
   echo "ERROR:  Missing repository $HIP_REPO_DIR/"
   exit 1
fi

if [ ! -f $MLCC/bin/clang ] ; then
   echo "ERROR:  Missing file $MLCC/bin/clang"
   echo "        Build the MLCC llvm compiler in $MLCC first"
   echo "        This is needed to build the device libraries"
   echo " "
   exit 1
fi

# Make sure we can update the install directory
if [ "$1" == "install" ] ; then
   $SUDO mkdir -p $INSTALL_DIR
   $SUDO touch $INSTALL_DIR/testfile
   if [ $? != 0 ] ; then
      echo "ERROR: No update access to $INSTALL_DIR"
      exit 1
   fi
   $SUDO rm $INSTALL_DIR/testfile
fi

NUM_THREADS=
if [ ! -z `which "getconf"` ]; then
   NUM_THREADS=$(`which "getconf"` _NPROCESSORS_ONLN)
   if [ "$PROC" == "ppc64le" ] || [ "$PROC" == "aarch64" ] ; then
      NUM_THREADS=$(( NUM_THREADS / 2))
   fi

fi

if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then

  if [ -d "$BUILD_DIR/hip" ] ; then
     echo
     echo "FRESH START , CLEANING UP FROM PREVIOUS BUILD"
     echo rm -rf $BUILD_DIR/hip
     rm -rf $BUILD_DIR/hip
  fi

  MYCMAKEOPTS="-DCMAKE_BUILD_TYPE=$BUILDTYPE -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR"
# -DBUILD_SHARED_LIBS=ON -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DLLVM_DIR=$LLVM_BUILD/lib/cmake/llvm"

  mkdir -p $BUILD_DIR/hip
  cd $BUILD_DIR/hip
  echo " -----Running hip cmake ---- "
  echo cmake $MYCMAKEOPTS $HIP_REPO_DIR
  cmake $MYCMAKEOPTS $HIP_REPO_DIR
  if [ $? != 0 ] ; then
      echo "ERROR hip cmake failed. Cmake flags"
      echo "      $MYCMAKEOPTS"
      exit 1
  fi

fi

cd $BUILD_DIR/hip
echo
echo " -----Running make for hip ---- "
#make -j $NUM_THREADS 
make 
if [ $? != 0 ] ; then
      echo " "
      echo "ERROR: make -j $NUM_THREADS  FAILED"
      echo "To restart:"
      echo "  cd $BUILD_DIR/hip"
      echo "  make "
      exit 1
fi

#  ----------- Install only if asked  ----------------------------
if [ "$1" == "install" ] ; then
      cd $BUILD_DIR/hip
      echo
      echo " -----Installing to $INSTALL_DIR ----- "
      $SUDO make install
      if [ $? != 0 ] ; then
         echo "ERROR make install failed "
         exit 1
      fi
fi
