#!/bin/bash
#
#  build_openmp.sh:  Script to build the HCC2 runtime libraries and debug libraries.  
#                This script will install in location defined by HCC2 env variable
#
# Do not change these values. If you set the environment variables these defaults will changed to 
# your environment variables
HCC2=${HCC2:-/opt/rocm/hcc2}
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
BUILD_HCC2=${BUILD_HCC2:-$HCC2_REPOS}
OPENMP_REPO_NAME=${OPENMP_REPO_NAME:-openmp}
REPO_BRANCH=${REPO_BRANCH:-HCC2-181213}

# We can now provide a list of sm architectures, but they must support long long maxAtomic 
# Only Cuda 9 and above supports sm_70
NVPTXGPUS_DEFAULT="30,35,50,60"
if [ -f /usr/local/cuda/version.txt ] ; then
  if [ `head -1 /usr/local/cuda/version.txt | cut -d " " -f 3 | cut -d "." -f 1` -ge 9 ] ; then
    NVPTXGPUS_DEFAULT+=",70"
  fi
fi

NVPTXGPUS=${NVPTXGPUS:-"${NVPTXGPUS_DEFAULT}"}

# Also provide a list of GFX processors to build for
GFXLIST=${GFXLIST:-"gfx700 gfx701 gfx801 gfx803 gfx900"}
export GFXLIST

SUDO=${SUDO:-set}

if [ "$SUDO" == "set" ] ; then 
   SUDO="sudo"
else 
   SUDO=""
fi

BUILD_DIR=$BUILD_HCC2
if [ "$BUILD_DIR" != "$HCC2_REPOS" ] ; then 
   COPYSOURCE=true
fi

# Get the HCC2_VERSION_STRING from a file in this directory 
function getdname(){
   local __DIRN=`dirname "$1"`
   if [ "$__DIRN" = "." ] ; then
      __DIRN=$PWD;
   else
      if [ ${__DIRN:0:1} != "/" ] ; then
         if [ ${__DIRN:0:2} == ".." ] ; then
               __DIRN=`dirname $PWD`/${__DIRN:3}
         else
            if [ ${__DIRN:0:1} = "." ] ; then
               __DIRN=$PWD/${__DIRN:2}
            else
               __DIRN=$PWD/$__DIRN
            fi
         fi
      fi
   fi
   echo $__DIRN
}

thisdir=$(getdname $0)
[ ! -L "$0" ] || thisdir=$(getdname `readlink "$0"`)
if [ -f $thisdir/HCC2_VERSION_STRING ] ; then 
   HCC2_VERSION_STRING=`cat $thisdir/HCC2_VERSION_STRING`
else 
   HCC2_VERSION_STRING=${HCC2_VERSION_STRING:-"0.5-2"}
fi
export HCC2_VERSION_STRING
INSTALL_DIR=${INSTALL_OPENMP:-"${HCC2}_${HCC2_VERSION_STRING}"}

if [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] ; then 
  echo " "
  echo "Example commands and actions: "
  echo "  ./build_openmp.sh                   cmake, make, NO Install "
  echo "  ./build_openmp.sh nocmake           NO cmake, make, NO install "
  echo "  ./build_openmp.sh install           NO Cmake, make, INSTALL"
  echo " "
  echo "To build hcc2, you need to build 5 components with these commands"
  echo " "
  echo "  ./build_hcc2.sh "
  echo "  ./build_hcc2.sh install"
  echo "  ./build_utils.sh"
  echo "  ./build_atmi.sh install"
  echo "  ./build_atmi.sh"
  echo "  ./build_atmi.sh install"
  echo "  ./build_openmp.sh "
  echo "  ./build_openmp.sh install"
  echo "  ./build_libdevice.sh"
  echo "  ./build_libdevice.sh install"
  echo "  ./build_hiprt.sh "
  echo "  ./build_hiprt.sh install"
  echo " "
  exit 
fi

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
   echo "-- Repository $REPO_DIR is correctly on branch $REPO_BRANCH"
}
REPO_DIR=$HCC2_REPOS/$OPENMP_REPO_NAME
checkrepo

PROC=`uname -p`
if [ "$PROC" == "aarch64" ] ; then
   NVPTXGPUS_DEFAULT=""
else
   CUDAH=`find /usr/local/cuda/targets -type f -name "cuda.h" 2>/dev/null`
   if [ "$CUDAH" == "" ] ; then
      CUDAH=`find /usr/local/cuda/include -type f -name "cuda.h" 2>/dev/null`
   fi
   if [ "$CUDAH" == "" ] ; then
      echo
      echo "ERROR:  THE cuda.h FILE WAS NOT FOUND WITH ARCH $PROC"
      echo "        A CUDA installation is necessary to build libomptarget deviceRTLs"
      echo "        Please install CUDA to build hcc2-rt"
      echo
      exit 1
   fi
   # I don't see now nvcc is called, but this eliminates the deprecated warnings
   export CUDAFE_FLAGS="-w"
fi

if [ ! -d $HCC2_REPOS/$OPENMP_REPO_NAME ] ; then 
   echo "ERROR:  Missing repository $HCC2_REPOS/$OPENMP_REPO_NAME "
   echo "        Consider setting env variables HCC2_REPOS and/or OPENMP_REPO_NAME "
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
fi

GCCMIN=5
if [ -f /usr/local/cuda/bin/nvcc ] ; then
   CUDAVER=`/usr/local/cuda/bin/nvcc --version | grep compilation | cut -d" " -f5 | cut -d"." -f1 `
   echo "CUDA VERSION IS $CUDAVER"
   if [ $CUDAVER -gt 8 ] ; then
     GCCMIN=7
   fi
fi

function getgcc5orless(){
   _loc=`which gcc`
   [ "$_loc" == "" ] && return
   gccver=`$_loc --version | grep gcc | cut -d")" -f2 | cut -d"." -f1`
   [ $gccver -gt $GCCMIN ] && _loc=`which gcc-$GCCMIN`
   echo $_loc
}
function getgxx5orless(){
   _loc=`which g++`
   [ "$_loc" == "" ] && return
   gxxver=`$_loc --version | grep g++ | cut -d")" -f2 | cut -d"." -f1`
   [ $gxxver -gt $GCCMIN ] && _loc=`which g++-$GCCMIN`
   echo $_loc
}

if [ "$PROC" == "ppc64le" ] ; then
   GCCLOC=`which gcc`
   GXXLOC=`which g++`
else
   GCCLOC=$(getgcc5orless)
   GXXLOC=$(getgxx5orless)
fi
if [ "$GCCLOC" == "" ] ; then
   echo "ERROR: NO ADEQUATE gcc"
   echo "       Please install gcc-5"
   exit 1
fi
if [ "$GXXLOC" == "" ] ; then
   echo "ERROR: NO ADEQUATE g++"
   echo "       Please install g++-5"
   exit 1
fi

COMMON_CMAKE_OPTS="-DOPENMP_ENABLE_LIBOMPTARGET=1
-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR
-DOPENMP_TEST_C_COMPILER=$HCC2/bin/clang
-DOPENMP_TEST_CXX_COMPILER=$HCC2/bin/clang++
-DLIBOMPTARGET_NVPTX_ENABLE_BCLIB=ON
-DLIBOMPTARGET_NVPTX_CUDA_COMPILER=$HCC2/bin/clang++
-DLIBOMPTARGET_NVPTX_ALTERNATE_HOST_COMPILER=$GCCLOC
-DLIBOMPTARGET_NVPTX_BC_LINKER=$HCC2/bin/llvm-link
-DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES=$NVPTXGPUS"

export HSA_RUNTIME_PATH=$INSTALL_DIR/hsa

if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then 

   echo " " 
   echo "This is a FRESH START. ERASING any previous builds in $BUILD_DIR/$OPENMP_REPO_NAME "
   echo "Use ""$0 nocmake"" or ""$0 install"" to avoid FRESH START."

   if [ $COPYSOURCE ] ; then 
      mkdir -p $BUILD_DIR/$OPENMP_REPO_NAME
      echo rsync -av --exclude ".git" --delete $HCC2_REPOS/$OPENMP_REPO_NAME/ $BUILD_DIR/$OPENMP_REPO_NAME/ 
      rsync -av --exclude ".git" --delete $HCC2_REPOS/$OPENMP_REPO_NAME/ $BUILD_DIR/$OPENMP_REPO_NAME/ 
   fi

      echo rm -rf $BUILD_DIR/build/openmp
      rm -rf $BUILD_DIR/build/openmp
      MYCMAKEOPTS="$COMMON_CMAKE_OPTS -DCMAKE_BUILD_TYPE=Release"
      mkdir -p $BUILD_DIR/build/openmp
      cd $BUILD_DIR/build/openmp
      echo " -----Running openmp cmake ---- " 
      echo cmake $MYCMAKEOPTS  $BUILD_DIR/$OPENMP_REPO_NAME
      cmake $MYCMAKEOPTS  $BUILD_DIR/$OPENMP_REPO_NAME
      if [ $? != 0 ] ; then 
         echo "ERROR openmp cmake failed. Cmake flags"
         echo "      $MYCMAKEOPTS"
         exit 1
      fi

      echo rm -rf $BUILD_DIR/build/openmp_debug
      rm -rf $BUILD_DIR/build/openmp_debug
      export OMPTARGET_DEBUG=1
      MYCMAKEOPTS="$COMMON_CMAKE_OPTS -DLIBOMPTARGET_NVPTX_DEBUG=ON -DCMAKE_BUILD_TYPE=Debug -DOMPTARGET_DEBUG=1"
      mkdir -p $BUILD_DIR/build/openmp_debug
      cd $BUILD_DIR/build/openmp_debug
      echo
      echo " -----Running openmp cmake for debug ---- " 
      echo cmake $MYCMAKEOPTS  $BUILD_DIR/$OPENMP_REPO_NAME
      cmake $MYCMAKEOPTS  $BUILD_DIR/$OPENMP_REPO_NAME
      if [ $? != 0 ] ; then 
         echo "ERROR openmp debug cmake failed. Cmake flags"
         echo "      $MYCMAKEOPTS"
         exit 1
      fi
fi

cd $BUILD_DIR/build/openmp
echo
echo " -----Running make for $BUILD_DIR/build/openmp ---- "
make -j $NUM_THREADS
if [ $? != 0 ] ; then 
      echo " "
      echo "ERROR: make -j $NUM_THREADS  FAILED"
      echo "To restart:" 
      echo "  cd $BUILD_DIR/build/openmp"
      echo "  make"
      exit 1
fi

cd $BUILD_DIR/build/openmp_debug
echo
echo
echo " -----Running make for $BUILD_DIR/build/openmp_debug ---- "
export OMPTARGET_DEBUG=1
make -j $NUM_THREADS
if [ $? != 0 ] ; then 
      echo "ERROR make -j $NUM_THREADS failed"
      exit 1
else
   if [ "$1" != "install" ] ; then 
      echo
      echo "Successful build of ./build_openmp.sh .  Please run:"
      echo "  ./build_openmp.sh install "
      echo "to install into directory $INSTALL_DIR/lib and $INSTALL_DIR/lib-debug"
      echo
  fi
fi

#  ----------- Install only if asked  ----------------------------
if [ "$1" == "install" ] ; then 
      cd $BUILD_DIR/build/openmp
      echo
      echo " -----Installing to $INSTALL_DIR/lib ----- " 
      $SUDO make install 
      if [ $? != 0 ] ; then 
         echo "ERROR make install failed "
         exit 1
      fi
      cd $BUILD_DIR/build/openmp_debug
      echo
      echo " -----Installing to $INSTALL_DIR/lib-debug ---- " 
      $SUDO make install 
      if [ $? != 0 ] ; then 
         echo "ERROR make install failed "
         exit 1
      fi
fi
