#!/bin/bash
#
#  build_rocr.sh:  Script to build the rocm runtime and install into the hcc2 compiler installation
#                  Requires that "build_roct.sh install" be installed first
#
# Do not change these values. If you set the environment variables these defaults will changed to 
# your environment variables
HCC2=${HCC2:-/opt/rocm/hcc2}
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
ROCR_REPO_NAME=${ROCM_REPO_NAME:-rocr-runtime}
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

thisdir=$(getdname $0)
[ ! -L "$0" ] || thisdir=$(getdname `readlink "$0"`)
if [ -f $thisdir/HCC2_VERSION_STRING ] ; then 
   HCC2_VERSION_STRING=`cat $thisdir/HCC2_VERSION_STRING`
else 
   HCC2_VERSION_STRING=${HCC2_VERSION_STRING:-"0.4-0"}
fi
export HCC2_VERSION_STRING
INSTALL_DIR=${INSTALL_ROCM:-"${HCC2}_${HCC2_VERSION_STRING}"}
ROCT_DIR=${ROCT:-"${INSTALL_DIR}"}

REPO_BRANCH=${REPO_BRANCH:-roc-1.9.x}
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
REPO_DIR=$HCC2_REPOS/$ROCR_REPO_NAME
checkrepo

if [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] ; then 
  echo " "
  echo " This script builds the ROCM runtime libraries"
  echo " It gets the source from:  $HCC2_REPOS/$ROCR_REPO_NAME"
  echo " It builds libraries in:   $BUILD_HCC2/build/rocr"
  echo " It installs in:           $INSTALL_DIR"
  echo " "
  echo "Example commands and actions: "
  echo "  ./build_rocr.sh                   cmake, make , NO Install "
  echo "  ./build_rocr.sh nocmake           NO cmake, make, NO install "
  echo "  ./build_rocr.sh install           NO Cmake, make , INSTALL"
  echo " "
  echo "To build hcc2, see the README file in this directory"
  echo " "
  exit 
fi

if [ ! -d $HCC2_REPOS/$ROCR_REPO_NAME ] ; then 
   echo "ERROR:  Missing repository $HCC2_REPOS/$ROCR_REPO_NAME"
   echo "        Are environment variables HCC2_REPOS and ROCR_REPO_NAME set correctly?"
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

cd $HCC2_REPOS/$ROCR_REPO_NAME
echo patch -p1 $thisdir/rocr-runtime.patch
patch -p1 < $thisdir/rocr-runtime.patch

if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then 

   echo " " 
   echo "This is a FRESH START. ERASING any previous builds in $BUILD_HCC2/build_rocr"
   echo "Use ""$0 nocmake"" or ""$0 install"" to avoid FRESH START."

   BUILDTYPE="Release"
   echo rm -rf $BUILD_HCC2/build/rocr
   rm -rf $BUILD_HCC2/build/rocr
   MYCMAKEOPTS="-DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_BUILD_TYPE=$BUILDTYPE -DHSAKMT_INC_PATH=$ROCT_DIR/include -DHSAKMT_LIB_PATH=$ROCT_DIR/lib"
   mkdir -p $BUILD_HCC2/build/rocr
   cd $BUILD_HCC2/build/rocr
   echo " -----Running rocr cmake ---- " 
   echo cmake $MYCMAKEOPTS  $HCC2_REPOS/$ROCR_REPO_NAME/src
   cmake $MYCMAKEOPTS  $HCC2_REPOS/$ROCR_REPO_NAME/src
   if [ $? != 0 ] ; then 
      echo "ERROR rocr cmake failed. cmake flags"
      echo "      $MYCMAKEOPTS"
      cd $HCC2_REPOS/$ROCR_REPO_NAME
      echo patch -p1 -R  $thisdir/rocr-runtime.patch
      patch -p1 -R < $thisdir/rocr-runtime.patch
      exit 1
   fi

fi

cd $BUILD_HCC2/build/rocr
echo
echo " -----Running make for rocr ---- " 
echo make -j $NUM_THREADS
make -j $NUM_THREADS
if [ $? != 0 ] ; then 
      echo " "
      echo "ERROR: make -j $NUM_THREADS  FAILED"
      echo "To restart:" 
      echo "  cd $BUILD_HCC2/build/rocr"
      echo "  make"
      cd $HCC2_REPOS/$ROCR_REPO_NAME
      echo patch -p1 -R $thisdir/rocr-runtime.patch
      patch -p1 -R < $thisdir/rocr-runtime.patch
      exit 1
fi

#  ----------- Install only if asked  ----------------------------
if [ "$1" == "install" ] ; then 
      cd $BUILD_HCC2/build/rocr
      echo " -----Installing to $INSTALL_DIR/lib ----- " 
      echo $SUDO make install 
      $SUDO make install 
      if [ $? != 0 ] ; then 
         echo "ERROR make install failed "
         cd $HCC2_REPOS/$ROCR_REPO_NAME
         echo patch -p1 -R  $thisdir/rocr-runtime.patch
         patch -p1 -R < $thisdir/rocr-runtime.patch
         exit 1
      fi
fi

cd $HCC2_REPOS/$ROCR_REPO_NAME
echo patch -p1 -R $thisdir/rocr-runtime.patch
patch -p1 -R < $thisdir/rocr-runtime.patch
