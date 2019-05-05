#!/bin/bash
#
#  clone_hcc2.sh:  Clone the repositories needed to build the hcc2 compiler.  
#                  Currently HCC2 needs 14 repositories.
#
# This script and other utility scripts are now kept in the bin directory of the hcc2 repository 
#
GITROC="https://github.com/radeonopencompute"
GITROCDEV="https://github.com/ROCm-Developer-Tools"
GITROCLIB="https://github.com/AMDComputeLibraries"
GITKHRONOS="https://github.com/KhronosGroup"

# Set the directory location for all HCC2 git REPOS
HCC2_REPOS=${HCC2_REPOS:-/home/$USER/git/hcc2}

# Set the HCC2 VERSION STRING. 
# Warning: Do not override this unless you are very sure
# After a release, we update this to the next value for developers
HCC2_VERSION_STRING=${HCC2_VERSION_STRING:-"0.5-5"}
export HCC2_VERSION_STRING

# The  git repos and branches that the HCC2 build scripts need
HCC2_MAIN_REPO_NAME=${HCC2_MAIN_REPO_NAME:-hcc2}
HCC2_MAIN_REPO_BRANCH=${HCC2_MAIN_REPO_BRANCH:-master}
HCC2_LLVM_REPO_NAME=${HCC2_LLVM_REPO_NAME:-llvm}
HCC2_LLVM_REPO_BRANCH=${HCC2_LLVM_REPO_BRANCH:-HCC2-181213}
HCC2_CLANG_REPO_NAME=${HCC2_CLANG_REPO_NAME:-clang}
HCC2_CLANG_REPO_BRANCH=${HCC2_CLANG_REPO_BRANCH:-HCC2-181213}
HCC2_LLD_REPO_NAME=${HCC2_LLD_REPO_NAME:-lld}
HCC2_LLD_REPO_BRANCH=${HCC2_LLD_REPO_BRANCH:-HCC2-181213}
HCC2_OMP_REPO_NAME=${HCC2_OMP_REPO_NAME:-openmp}
HCC2_OMP_REPO_BRANCH=${HCC2_OMP_REPO_BRANCH:-HCC2-181213}
HCC2_LIBDEVICE_REPO_NAME=${HCC2_LIBDEVICE_REPO_NAME:-rocm-device-libs}
HCC2_LIBDEVICE_REPO_BRANCH=${HCC2_LIBDEVICE_REPO_BRANCH:-HCC2-181210}
HCC2_OCLRUNTIME_REPO_NAME=${HCC2_OCLRUNTIME_REPO_NAME:-rocm-opencl-runtime}
HCC2_OCLRUNTIME_REPO_BRANCH=${HCC2_OCLRUNTIME_REPO_BRANCH:-roc-1.9.x}
HCC2_OCLDRIVER_REPO_NAME=${HCC2_OCLDRIVER_REPO_NAME:-rocm-opencl-driver}
HCC2_OCLDRIVER_REPO_BRANCH=${HCC2_OCLDRIVER_REPO_BRANCH:-roc-1.9.x}
HCC2_OCLICD_REPO_NAME=${HCC2_OCLICD_REPO_NAME:-opencl-icd-loader}
HCC2_OCLICD_REPO_BRANCH=${HCC2_OCLICD_REPO_BRANCH:-master}
HCC2_HIP_REPO_NAME=${HCC2_HIP_REPO_NAME:-hip}
HCC2_HIP_REPO_BRANCH=${HCC2_HIP_REPO_BRANCH:-HCC2.180805}
HCC2_ROCT_REPO_NAME=${HCC2_ROCT_REPO_NAME:-roct-thunk-interface}
HCC2_ROCT_REPO_BRANCH=${HCC2_ROCT_REPO_BRANCH:-roc-1.9.x}
HCC2_ROCR_REPO_NAME=${HCC2_ROCR_REPO_NAME:-rocr-runtime}
HCC2_ROCR_REPO_BRANCH=${HCC2_ROCR_REPO_BRANCH:-roc-1.9.x}
HCC2_ATMI_REPO_NAME=${HCC2_ATMI_REPO_NAME:-atmi}
HCC2_ATMI_REPO_BRANCH=${HCC2_ATMI_REPO_BRANCH:-atmi-0.5}
HCC2_APPS_REPO_NAME=${HCC2_APPS_REPO_NAME:-openmpapps}
HCC2_APPS_REPO_BRANCH=${HCC2_APPS_REPO_BRANCH:-HCC2-0.5}

STASH_BEFORE_PULL=${STASH_BEFORE_PULL:-YES}

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


function clone_or_pull(){
repodirname=$HCC2_REPOS/$reponame
echo
if [ -d $repodirname  ] ; then 
   echo "--- Pulling updates to existing dir $repodirname ----"
   echo "    We assume this came from an earlier clone of $repo_web_location/$reponame"
   # FIXME look in $repodir/.git/config to be sure 
   cd $repodirname
   if [ "$STASH_BEFORE_PULL" == "YES" ] ; then
      git stash -u
   fi
   echo "cd $repodirname ; git checkout $COBRANCH"
   git checkout $COBRANCH
   echo "git pull "
   git pull 
else 
   echo --- NEW CLONE of repo $reponame to $repodirname ----
   cd $HCC2_REPOS
   echo git clone $repo_web_location/$reponame
   git clone $repo_web_location/$reponame $reponame
   echo "cd $repodirname ; git checkout $COBRANCH"
   cd $repodirname
   git checkout $COBRANCH
fi
}

mkdir -p $HCC2_REPOS

# ---------------------------------------
#  The following REPOS are in ROCm-Development
# ---------------------------------------
repo_web_location=$GITROCDEV

reponame=$HCC2_MAIN_REPO_NAME
COBRANCH=$HCC2_MAIN_REPO_BRANCH
#clone_or_pull

reponame=$HCC2_OMP_REPO_NAME
COBRANCH=$HCC2_OMP_REPO_BRANCH
clone_or_pull

reponame=$HCC2_LLVM_REPO_NAME
COBRANCH=$HCC2_LLVM_REPO_BRANCH
clone_or_pull

reponame=$HCC2_CLANG_REPO_NAME
COBRANCH=$HCC2_CLANG_REPO_BRANCH
clone_or_pull

reponame=$HCC2_LLD_REPO_NAME
COBRANCH=$HCC2_LLD_REPO_BRANCH
clone_or_pull

reponame=$HCC2_HIP_REPO_NAME
COBRANCH=$HCC2_HIP_REPO_BRANCH
clone_or_pull

# ---------------------------------------
# The following repos are in RadeonOpenCompute
# ---------------------------------------
repo_web_location=$GITROC

reponame=$HCC2_LIBDEVICE_REPO_NAME
COBRANCH=$HCC2_LIBDEVICE_REPO_BRANCH
clone_or_pull

reponame=$HCC2_ROCT_REPO_NAME
COBRANCH=$HCC2_ROCT_REPO_BRANCH
clone_or_pull

reponame=$HCC2_ROCR_REPO_NAME
COBRANCH=$HCC2_ROCR_REPO_BRANCH
clone_or_pull

reponame=$HCC2_ATMI_REPO_NAME
COBRANCH=$HCC2_ATMI_REPO_BRANCH
clone_or_pull

reponame=$HCC2_OCLDRIVER_REPO_NAME
COBRANCH=$HCC2_OCLDRIVER_REPO_BRANCH
clone_or_pull

reponame=$HCC2_OCLRUNTIME_REPO_NAME
COBRANCH=$HCC2_OCLRUNTIME_REPO_BRANCH
clone_or_pull

# ---------------------------------------
# The following repos is in AMDComputeLibraries
# ---------------------------------------
repo_web_location=$GITROCLIB
reponame=$HCC2_APPS_REPO_NAME
COBRANCH=$HCC2_APPS_REPO_BRANCH
clone_or_pull

# ---------------------------------------
# The following repo is in KhronosGroup
# ---------------------------------------
repo_web_location=$GITKHRONOS
reponame=$HCC2_OCLICD_REPO_NAME
COBRANCH=$HCC2_OCLICD_REPO_BRANCH
clone_or_pull
