#!/bin/bash
#
#   build_fixups.sh : make some fixes to the installation.
#                     We eventually need to remove this hack.
#
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

#HCC2=${HCC2:-/opt/rocm/hcc2}
#HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
MLCC_REPOS=${MLCC_REPOS:-$THIS_SCRIPT_DIR/../..}
MLCC_REPO_NAME=${HCC2_REPO_NAME:-mlcc}

MLCC_BUILD_DIR=${MLCC_BUILD_DIR:-$MLCC_REPOS/build}
MLCC_BUILD_DIR_LLVM=$MLCC_BUILD_DIR/llvm

SUDO=${SUDO:-set}
if [ "$SUDO" == "set" ]  || [ "$SUDO" == "yes" ] || [ "$SUDO" == "YES" ] ; then
   SUDO="sudo"
else
   SUDO=""
fi

# Temporarily remove debug libdevice and replace with release 
savedir=$PWD
echo cd $MLCC_BUILD_DIR_LLVM/lib-debug
cd $MLCC_BUILD_DIR_LLVM/lib-debug
if [ -L libdevice ] ; then
   $SUDO rm libdevice
fi
if [ -d libdevice ] ; then
  $SUDO rm -rf libdevice
fi
# Now link to nondefault libdevice
echo $SUDO ln -sf ../lib/libdevice libdevice
$SUDO ln -sf ../lib/libdevice libdevice
cd $savedir

# Copy examples 
if [ -d $MLCC_BUILD_DIR/examples ] ; then 
  $SUDO rm -rf $MLCC_BUILD_DIR/examples
fi
echo $SUDO cp -rp $MLCC_REPOS/$MLCC_REPO_NAME/examples $MLCC_BUILD_DIR
$SUDO cp -rp $MLCC_REPOS/$MLCC_REPO_NAME/examples $MLCC_BUILD_DIR

echo "Done with $0"
