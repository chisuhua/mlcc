#!/bin/bash
#
#  File: build_libdevice.sh
#        build the ppu-libs libraries in $MLCC/lib/libdevice
#

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#HCC2=${HCC2:-/opt/rocm/hcc2}
#HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
MLCC_REPOS=${MLCC_REPOS:-$THIS_SCRIPT_DIR/../..}

# Do not change these values. Set the environment variables to override these defaults
MLCC_BUILD_DIR=${MLCC_BUILD_DIR:-$MLCC_REPOS/build}
MLCC_BUILD_DIR_LLVM=$MLCC_BUILD_DIR/llvm
MLCC=${MLCC:-$MLCC_BUILD_DIR_LLVM}

# change to use MLCC_BUILD_DIR
#BUILD_HCC2=${BUILD_HCC2:-$HCC2_REPOS}

MLCC_LIBDEVICE_REPO_NAME=${MLCC_LIBDEVICE_REPO_NAME:-ppu-libs}
# We now pickup HSA from the HCC2 install directory because it is built
# with build_roct.sh and build_rocr.sh . 
#HSA_DIR=${HSA_DIR:-$HCC2/hsa}

SKIPTEST=${SKIPTEST:-"YES"}
SUDO=${SUDO:-no}
if [ "$SUDO" == "set" ] ; then 
   SUDO="sudo"
else 
   SUDO=""
fi

BUILD_DIR=$MLCC_BUILD_DIR
if [ "$BUILD_DIR" != "$MLCC_REPOS" ] ; then 
   COPYSOURCE=true
fi

INSTALL_ROOT_DIR=${INSTALL_LIBDEVICE:-"${MLCC_BUILD_DIR_LLVM}"}
INSTALL_DIR=$INSTALL_ROOT_DIR/lib/libdevice

LLVM_BUILD=$MLCC_BUILD_DIR_LLVM
SOURCEDIR=$MLCC_REPOS/$MLCC_LIBDEVICE_REPO_NAME

REPO_BRANCH=${REPO_BRANCH:-HCC2-181210}
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
REPO_DIR=$MLCC_REPOS/$MLCC_LIBDEVICE_REPO_NAME

# TODO we skip checkrepo now
# checkrepo

#MYCMAKEOPTS="-DLLVM_DIR=$LLVM_BUILD -DBUILD_HC_LIB=ON -DBUILD_CUDA2GCN=ON -DROCM_DEVICELIB_INCLUDE_TESTS=OFF -DPREPARE_BUILTINS=$MLCC_BUILD_DIR_LLVM/bin/prepare-builtins"
MYCMAKEOPTS="-DLLVM_DIR=$LLVM_BUILD -DBUILD_HC_LIB=ON -DBUILD_CUDA2GCN=OFF -DBUILD_CUDA2PPU=ON -DROCM_DEVICELIB_INCLUDE_TESTS=OFF -DPREPARE_BUILTINS=$MLCC_BUILD_DIR_LLVM/bin/prepare-builtins"


if [ ! -d $MLCC_BUILD_DIR_LLVM/lib ] ; then 
  echo "ERROR: Directory $MLCC_BUILD_DIR_LLVM/lib is missing"
  echo "       MLCC must be installed in $MLCC_BUILD_DIR_LLVM to continue"
  exit 1
fi

PROC=`uname -p`
NUM_THREADS=
if [ ! -z `which "getconf"` ]; then
   NUM_THREADS=$(`which "getconf"` _NPROCESSORS_ONLN)
   if [ "$PROC" == "ppc64le" ] || [ "$PROC" == "aarch64" ] ; then
      NUM_THREADS=$(( NUM_THREADS / 2))
   fi
   # having problems on arm so ...
   if  [ "$PROC" == "aarch64" ] ; then
      NUM_THREADS=$(( NUM_THREADS / 4))
   fi
fi

# TODO mlvm
NUM_THREADS=1

# export LLVM_BUILD HSA_DIR
export LLVM_BUILD
export PATH=$LLVM_BUILD/bin:$PATH

if [ "$1" != "install" ] ; then 
   if [ $COPYSOURCE ] ; then 
      if [ -d $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME ] ; then 
         echo rm -rf $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME
         $SUDO rm -rf $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME
      fi
      mkdir -p $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME
      echo rsync -a $SOURCEDIR/ $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME/
      rsync -a $SOURCEDIR/ $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME/
      # Fixup ll files to avoid link warnings
      for llfile in `find $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME -type f | grep "\.ll" ` ; do 
        sed -i -e"s/:64-A5/:64-S32-A5/" $llfile
      done
   fi

      builddir_libdevice=$BUILD_DIR/libdevice
      if [ -d $builddir_libdevice ] ; then 
         echo rm -rf $builddir_libdevice
         # need SUDO because a previous make install was done with sudo 
         $SUDO rm -rf $builddir_libdevice
      fi
      mkdir -p $builddir_libdevice
      cd $builddir_libdevice
      echo 
      echo DOING BUILD in Directory $builddir_libdevice
      echo 

      CC="$LLVM_BUILD/bin/clang"
      export CC
      echo "cmake $MYCMAKEOPTS -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME"
      cmake $MYCMAKEOPTS -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME
      if [ $? != 0 ] ; then 
         echo "ERROR cmake failed  command was \n"
         echo "      cmake $MYCMAKEOPTS -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $BUILD_DIR/$MLCC_LIBDEVICE_REPO_NAME"
         exit 1
      fi
      echo "make -j $NUM_THREADS"
      make -j $NUM_THREADS 
      if [ $? != 0 ] ; then 
         echo "ERROR make failed "
         exit 1
      fi


   echo 
   echo "  Done with all makes"
   echo "  Please run ./build_libdevice.sh install "
   echo 

   if [ "$SKIPTEST" != "YES" ] ; then 
         builddir_libdevice=$BUILD_DIR/libdevice
         cd $builddir_libdevice
         echo "running tests in $builddir_libdevice"
         make test 
      echo 
      echo "# done with all tests"
      echo 
   fi
fi

if [ "$1" == "install" ] ; then 
   echo 
   echo mkdir -p $INSTALL_DIR/include
   $SUDO mkdir -p $INSTALL_DIR/include
   $SUDO mkdir -p $INSTALL_DIR/lib
   builddir_libdevice=$BUILD_DIR/libdevice
   echo "running make install from $builddir_libdevice"
   cd $builddir_libdevice
   echo $SUDO make -j $NUM_THREADS install
   $SUDO make -j $NUM_THREADS install

   # rocm-device-lib cmake installs to lib dir, move all bc files up one level
   # and cleanup unused oclc_isa_version bc files and link correct one
   echo
   echo "POST-INSTALL REORG OF SUBDIRECTORIES $INSTALL_DIR"
   echo "--"
   echo "-- $INSTALL_DIR"
   echo "-- MOVING bc FILES FROM lib DIRECTORY UP ONE LEVEL"
   $SUDO mv $INSTALL_DIR/lib/*.bc $INSTALL_DIR
   $SUDO rm -rf $INSTALL_DIR/lib/cmake
   $SUDO rmdir $INSTALL_DIR/lib 

   # END OF POST-INSTALL REORG 

   echo 
   echo " $0 Installation complete into $INSTALL_DIR"
   echo 
fi
