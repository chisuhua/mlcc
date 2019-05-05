#!/bin/bash
#
#  build_atmi.sh:  Script to build the HCC2 atmi libraries and debug libraries.  
#
# Do not change these values. If you set the environment variables these defaults will changed to 
# your environment variables
HCC2=${HCC2:-/opt/rocm/hcc2}
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
ATMI_REPO_NAME=${ATMI_REPO_NAME:-atmi}
BUILD_HCC2=${BUILD_HCC2:-$HCC2_REPOS}

SUDO=${SUDO:-set}
if [ "$SUDO" == "set" ] ; then 
   SUDO="sudo"
else 
   SUDO=""
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

GFXLIST=${GFXLIST:-"gfx700 gfx701 gfx801 gfx803 gfx900"}
export GFXLIST

thisdir=$(getdname $0)
[ ! -L "$0" ] || thisdir=$(getdname `readlink "$0"`)
if [ -f $thisdir/HCC2_VERSION_STRING ] ; then 
   HCC2_VERSION_STRING=`cat $thisdir/HCC2_VERSION_STRING`
else 
   HCC2_VERSION_STRING=${HCC2_VERSION_STRING:-"0.4-0"}
fi
export HCC2_VERSION_STRING
INSTALL_DIR=${INSTALL_ATMI:-"${HCC2}_${HCC2_VERSION_STRING}"}

# FIXME : pickup atmi from fixed dev branch
REPO_BRANCH=${REPO_BRANCH:-atmi-0.5}
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
REPO_DIR=$HCC2_REPOS/$ATMI_REPO_NAME
checkrepo

if [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] ; then 
  echo " "
  echo " This script builds release and debug versions of ATMI libraries."
  echo " It gets the source from:  $HCC2_REPOS/$ATMI_REPO_NAME"
  echo " It builds libraries in:   $BUILD_HCC2/build/atmi"
  echo "    and:                   $BUILD_HCC2/build/atmi_debug"
  echo " It installs in:           $INSTALL_DIR"
  echo " "
  echo "Example commands and actions: "
  echo "  ./build_atmi.sh                   cmake, make , NO Install "
  echo "  ./build_atmi.sh nocmake           NO cmake, make, NO install "
  echo "  ./build_atmi.sh install           NO Cmake, make , INSTALL"
  echo " "
  exit 
fi

if [ ! -d $HCC2_REPOS/$ATMI_REPO_NAME ] ; then 
   echo "ERROR:  Missing repository $HCC2_REPOS/$ATMI_REPO_NAME"
   echo "        Are environment variables HCC2_REPOS and ATMI_REPO_NAME set correctly?"
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

PROC=`uname -p`
if [ "$PROC" == "ppc64le" ] ||  [ "$PROC" == "aarch64" ] ; then
# FIXME: CHANGE THIS TO $INSTALL_DIR/hsa to see if ldd libatmi_rutime shows libhsa-runtime64, 
#        if not, then try to set rpath when building the library
   export HSA_DIR=$INSTALL_DIR
   HSACMAKEOPTS="-DHSA_DIR=$HSA_DIR"
else
   HSACMAKEOPTS=""
fi

NUM_THREADS=
if [ ! -z `which "getconf"` ]; then
    NUM_THREADS=$(`which "getconf"` _NPROCESSORS_ONLN)
fi

if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then 

   echo " " 
   echo "This is a FRESH START. ERASING any previous builds in $BUILD_HCC2/build_atmi"
   echo "Use ""$0 nocmake"" or ""$0 install"" to avoid FRESH START."

   BUILDTYPE="Release"
   echo rm -rf $BUILD_HCC2/build/atmi
   rm -rf $BUILD_HCC2/build/atmi
   MYCMAKEOPTS="-DLLVM_DIR=$HCC2 -DCMAKE_BUILD_TYPE=$BUILDTYPE -DATMI_HSA_INTEROP=on -DATMI_WITH_HCC2=on -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $HSACMAKEOPTS"
   mkdir -p $BUILD_HCC2/build/atmi
   cd $BUILD_HCC2/build/atmi
   echo " -----Running atmi cmake ---- " 
   echo cmake $MYCMAKEOPTS  $HCC2_REPOS/$ATMI_REPO_NAME/src
   cmake $MYCMAKEOPTS  $HCC2_REPOS/$ATMI_REPO_NAME/src
   if [ $? != 0 ] ; then 
      echo "ERROR atmi cmake failed. cmake flags"
      echo "      $MYCMAKEOPTS"
      exit 1
   fi

   BUILDTYPE="Debug"
   echo rm -rf $BUILD_HCC2/build/atmi_debug
   rm -rf $BUILD_HCC2/build/atmi_debug
   MYCMAKEOPTS="-DLLVM_DIR=$HCC2 -DCMAKE_BUILD_TYPE=$BUILDTYPE -DATMI_HSA_INTEROP=on -DATMI_WITH_HCC2=on -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR $HSACMAKEOPTS "

   mkdir -p $BUILD_HCC2/build/atmi_debug
   cd $BUILD_HCC2/build/atmi_debug
   echo " -----Running atmi cmake for debug ---- " 
   cmake $MYCMAKEOPTS $HCC2_REPOS/$ATMI_REPO_NAME/src
   if [ $? != 0 ] ; then 
      echo "ERROR atmi debug cmake failed. cmake flags"
      echo "      $MYCMAKEOPTS"
      exit 1
  fi
fi

cd $BUILD_HCC2/build/atmi
echo
echo " -----Running make for atmi ---- " 
make -j $NUM_THREADS
if [ $? != 0 ] ; then 
      echo " "
      echo "ERROR: make -j $NUM_THREADS  FAILED"
      echo "To restart:" 
      echo "  cd $BUILD_HCC2/build/atmi"
      echo "  make"
      exit 1
fi

cd $BUILD_HCC2/build/atmi_debug
echo " -----Running make for lib-debug ---- " 
make -j $NUM_THREADS
if [ $? != 0 ] ; then 
      echo "ERROR make -j $NUM_THREADS failed"
      exit 1
fi

#  ----------- Install only if asked  ----------------------------
if [ "$1" == "install" ] ; then 
      cd $BUILD_HCC2/build/atmi
      echo " -----Installing to $INSTALL_DIR/lib ----- " 
      $SUDO make install 
      if [ $? != 0 ] ; then 
         echo "ERROR make install failed "
         exit 1
      fi
      cd $BUILD_HCC2/build/atmi_debug
      echo " -----Installing to $INSTALL_DIR/lib-debug ---- " 
      $SUDO make install 
      if [ $? != 0 ] ; then 
         echo "ERROR make install failed "
         exit 1
      fi
fi
