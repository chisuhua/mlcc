#!/bin/bash
#
#  File: build_libm.sh
#        buind the rocm-device-libs libraries in $HCC2/lib/libm/$MCPU
#        The rocm-device-libs get built for each processor in $GFXLIST
#        even though currently all rocm-device-libs are identical for each 
#        gfx processor (amdgcn)
#

# Do not change these values. Set the environment variables to override these defaults

HCC2=${HCC2:-/opt/rocm/hcc2}
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
BUILD_HCC2=${BUILD_HCC2:-$HCC2_REPOS}
HCC2_REPO_NAME=${HCC2_REPO_NAME:-hcc2}
INSTALL_DIR=${INSTALL_LIBM:-"${HCC2}"}

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

MCPU_LIST=${GFXLIST:-"gfx700 gfx701 gfx801 gfx803 gfx900"}

# build_libm now builds cross-platform DBCLs for libm
# Only Cuda 9 and above supports sm_70
NVPTXGPUS_DEFAULT="30,35,50,60"
if [ -f /usr/local/cuda/version.txt ] ; then
  if [ `head -1 /usr/local/cuda/version.txt | cut -d " " -f 3 | cut -d "." -f 1` -ge 9 ] ; then
    NVPTXGPUS_DEFAULT+=",70"
  fi
fi

NVPTXGPUS=${NVPTXGPUS:-"${NVPTXGPUS_DEFAULT}"}

LIBM_DIR_SRC="$HCC2_REPOS/$HCC2_REPO_NAME/examples/libdevice/libm"
LIBM_DIR="$BUILD_DIR/build/libm"
echo rsync -av $LIBM_DIR_SRC/ $LIBM_DIR/
rsync -av $LIBM_DIR_SRC/ $LIBM_DIR/

export PATH=$LLVM_BUILD/bin:$PATH

if [ "$1" != "install" ] ; then 
   savecurdir=$PWD
   cd $LIBM_DIR
   make clean-out
   for gpu in $MCPU_LIST ; do
      echo  
      echo "BUilding libm for $gpu"
      echo
      HCC2_GPU=$gpu make
      if [ $? != 0 ] ; then
	 echo 
         echo "ERROR make failed for HCC2_GPU = $gpu"
         exit 1
      fi
   done
   PROC=`uname -p`
   if [ "$PROC" == "aarch64" ] ; then
      echo "WARNING:  No cuda for aarch64 so skipping libm creation for $NVPTXGPUS"
   else
      origIFS=$IFS
      IFS=","
      for gpu in $NVPTXGPUS ; do
         echo  
         echo "BUilding libm for sm_$gpu"
         echo
         HCC2_GPU="sm_$gpu" make
         if [ $? != 0 ] ; then
	    echo 
            echo "ERROR make failed for HCC2_GPU = sm_$gpu"
            exit 1
         fi
      done
      IFS=$origIFS
   fi
   cd $savecurdir
   echo 
   echo "  Done! Please run ./build_libm.sh install "
   echo 
fi

if [ "$1" == "install" ] ; then 
   echo
   echo "INSTALLING DBCL libm from $LIBM_DIR/build "
   echo "rsync -av $LIBM_DIR/build/libdevice $INSTALL_DIR/lib"
   mkdir -p $INSTALL_DIR/lib
   $SUDO rsync -av $LIBM_DIR/build/libdevice $INSTALL_DIR/lib
   echo "rsync -av $LIBM_DIR/build/libdevice $INSTALL_DIR/lib-debug"
   mkdir -p $INSTALL_DIR/lib-debug
   $SUDO rsync -av $LIBM_DIR/build/libdevice $INSTALL_DIR/lib-debug
   echo 
   echo " $0 Installation complete into $INSTALL_DIR"
   echo 
fi
