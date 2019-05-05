#!/bin/bash
# 
#   build_hcc2.sh : Build all HCC2 components 
#
HCC2=${HCC2:-/opt/rocm/hcc2}
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}
HCC2_REPO_NAME=${HCC2_REPO_NAME:-hcc2}

function build_hcc2_component() {
   $HCC2_REPOS/$HCC2_REPO_NAME/bin/build_$COMPONENT.sh
   rc=$?
   if [ $rc != 0 ] ; then 
      echo " !!!  build_hcc2.sh: BUILD FAILED FOR COMPONENT $COMPONENT !!!"
      exit $rc
   fi  
   $HCC2_REPOS/$HCC2_REPO_NAME/bin/build_$COMPONENT.sh install
   rc=$?
   if [ $rc != 0 ] ; then 
      echo " !!!  build_hcc2.sh: INSTALL FAILED FOR COMPONENT $COMPONENT !!!"
      exit $rc
   fi  
}
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
INSTALL_DIR=${INSTALL_HCC2:-"${HCC2}_${HCC2_VERSION_STRING}"}

TOPSUDO=${SUDO:-set}
if [ "$TOPSUDO" == "set" ]  || [ "$TOPSUDO" == "yes" ] || [ "$TOPSUDO" == "YES" ] ; then
   TOPSUDO="sudo"
else
   TOPSUDO=""
fi

# Test update access to INSTALL_DIR
# This should be done early to ensure sudo (if set) does not prompt for password later
$TOPSUDO mkdir -p $INSTALL_DIR
if [ $? != 0 ] ; then
   echo "ERROR: $TOPSUDO mkdir failed, No update access to $INSTALL_DIR"
   exit 1
fi
$TOPSUDO touch $INSTALL_DIR/testfile
if [ $? != 0 ] ; then
   echo "ERROR: $TOPSUDO touch failed, No update access to $INSTALL_DIR"
   exit 1
fi
$TOPSUDO rm $INSTALL_DIR/testfile

echo 
date
echo " =================  START build_hcc2.sh ==================="   
echo 

components="roct rocr llvm utils hip atmi openmp libdevice libm"
for COMPONENT in $components ; do 
   echo 
   echo " =================  BUILDING COMPONENT $COMPONENT ==================="   
   echo 
   build_hcc2_component
   date
   echo " =================  DONE INSTALLING COMPONENT $COMPONENT ==================="   
done

$HCC2_REPOS/$HCC2_REPO_NAME/bin/build_fixups.sh
echo 
date
echo " =================  END build_hcc2.sh ==================="   
echo 
exit 0
