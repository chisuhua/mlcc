#!/bin/bash
# 
#  build_llvm.sh:  Script to build the llvm, clang , and lld components of the MLCC compiler. 
#                  This clang 8.0 compiler supports clang hip, OpenMP, and clang cuda
#                  offloading languages for BOTH nvidia and Radeon accelerator cards.
#                  This compiler has both the NVPTX and AMDGPU LLVM backends.
#                  The AMDGPU LLVM backend is referred to as the Lightning Compiler.
#
# See the help text below, run 'build_llvm.sh -h' for more information. 
#
#
THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Do not edit this script to change these values. 
# Simply set the environment variables to override these defaults

MLCC_REPOS=${MLCC_REPOS:-$THIS_SCRIPT_DIR/../..}
#MLCC_REPOS=${MLCC_REPOS:-/home/$USER/git/hcc2}

BUILD_TYPE=${BUILD_TYPE:-Release}
SUDO=${SUDO:-no}

MLCC_BUILD_DIR=${MLCC_BUILD_DIR:-$MLCC_REPOS/build}
MLCC_BUILD_DIR_LLVM=$MLCC_BUILD_DIR/llvm

MLCC_CLANG_REPO_NAME=${MLCC_CLANG_REPO_NAME:-clang}
MLCC_CLANG_REPO_BRANCH=${MLCC_CLANG_REPO_BRANCH:-MLCC-181213}
MLCC_LLVM_REPO_NAME=${LLVM_REPO_NAME:-llvm}
MLCC_LLVM_REPO_BRANCH=${MLCC_LLVM_REPO_BRANCH:-MLCC-181213}
MLCC_LLD_REPO_NAME=${MLCC_LLD_REPO_NAME:-lld}
MLCC_LLD_REPO_BRANCH=${MLCC_LLD_REPO_BRANCH:-MLCC-181213}

MLCC_LIBDEVICE_REPO_NAME=${MLCC_LIBDEVICE_REPO_NAME:-rocm-device-libs}
MLCC_LIBDEVICE_REPO_BRANCH=${MLCC_LIBDEVICE_REPO_BRANCH:-MLCC-181210}
MLCC_OCLRUNTIME_REPO_NAME=${MLCC_OCLRUNTIME_REPO_NAME:-rocm-opencl-runtime}
MLCC_OCLRUNTIME_REPO_BRANCH=${MLCC_OCLRUNTIME_REPO_BRANCH:-master}
MLCC_OCLDRIVER_REPO_NAME=${MLCC_OCLDRIVER_REPO_NAME:-rocm-opencl-driver}
MLCC_OCLDRIVER_REPO_BRANCH=${MLCC_OCLDRIVER_REPO_BRANCH:-master}
MLCC_OCLICD_REPO_NAME=${MLCC_OCLICD_REPO_NAME:-opencl-icd-loader}
MLCC_OCLICD_REPO_BRANCH=${MLCC_OCLICD_REPO_BRANCH:-master}

if [ "$SUDO" == "set" ]  || [ "$SUDO" == "yes" ] || [ "$SUDO" == "YES" ] ; then
   SUDO="sudo"
else 
   SUDO=""
fi

# Get the MLCC_VERSION_STRING from a file in this directory
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

# By default we build the sources from the repositories
# But you can force replication to another location for speed.
#BUILD_DIR="$MLCC_BUILD_DIR/.."
mkdir -p $MLCC_BUILD_DIR
BUILD_DIR="$( cd "$( dirname "$MLCC_BUILD_DIR" )" && pwd )"
MLCC_REPOS_DIR="$( cd "$( dirname "$MLCC_REPOS/mlcc" )" && pwd )"
# TODO we need also avoid copy if build at repo but not build subdirectory
if [ $BUILD_DIR != $MLCC_REPOS_DIR ] ; then 
  COPYSOURCE=true
fi

#thisdir=$(getdname $0)
#[ ! -L "$0" ] || thisdir=$(getdname `readlink "$0"`)
#if [ -f $thisdir/MLCC_VERSION_STRING ] ; then
if [ -f $THIS_SCRIPT_DIR/MLCC_VERSION_STRING ] ; then
   MLCC_VERSION_STRING=`cat $THIS_SCRIPT_DIR/MLCC_VERSION_STRING`
else
   MLCC_VERSION_STRING=${MLCC_VERSION_STRING:-"0.5-2"}
fi
export MLCC_VERSION_STRING
INSTALL_DIR=${INSTALL_MLCC:-"${MLCC}_${MLCC_VERSION_STRING}"}

#WEBSITE="http\:\/\/github.com\/ROCm-Developer-Tools\/hcc2"
WEBSITE="http\:\/\/github.com\/chisuhua\/mlcc"

PROC=`uname -p`
GCC=`which gcc`
GCPLUSCPLUS=`which g++`
if [ "$PROC" == "ppc64le" ] ; then 
   COMPILERS="-DCMAKE_C_COMPILER=/usr/bin/gcc-7 -DCMAKE_CXX_COMPILER=/usr/bin/g++-7"
   TARGETS_TO_BUILD="AMDGPU;NVPTX;PowerPC"
else
   COMPILERS="-DCMAKE_C_COMPILER=$GCC -DCMAKE_CXX_COMPILER=$GCPLUSCPLUS"
   if [ "$PROC" == "aarch64" ] ; then 
      TARGETS_TO_BUILD="AMDGPU;NVPTX;AArch64"
   else
      TARGETS_TO_BUILD="AMDGPU;X86;NVPTX"
   fi
fi
MYCMAKEOPTS="-DCMAKE_BUILD_TYPE=$BUILD_TYPE -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DLLVM_ENABLE_ASSERTIONS=ON"
MYCMAKEOPTS="$MYCMAKEOPTS -DLLVM_TARGETS_TO_BUILD=$TARGETS_TO_BUILD -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=RISCV $COMPILERS"
MYCMAKEOPTS="$MYCMAKEOPTS -DLLVM_VERSION_SUFFIX=_MLCC_Version_$MLCC_VERSION_STRING -DBUG_REPORT_URL='https://github.com/chisuhua/mlcc' -DCLANG_ANALYZER_ENABLE_Z3_SOLVER=0 -DLLVM_INCLUDE_BENCHMARKS=0"


if [ "$1" == "-h" ] || [ "$1" == "help" ] || [ "$1" == "-help" ] ; then 
  echo
  echo " build_llvm.sh is a smart clang/llvm compiler build script."
  echo
  echo " Repositories:"
  echo "    build_llvm.sh uses these local git repositories:"
  echo "    DIRECTORY                         BRANCH"
  echo "    ---------                         ------"
  echo "    $MLCC_REPOS/$MLCC_CLANG_REPO_NAME     $MLCC_CLANG_REPO_BRANCH"
  echo "    $MLCC_REPOS/$MLCC_LLVM_REPO_NAME      $MLCC_LLVM_REPO_BRANCH"
  echo "    $MLCC_REPOS/$MLCC_LLD_REPO_NAME       $MLCC_LLD_REPO_BRANCH"
  echo
  echo " Initial Build:"
  echo "    build_llvm.sh with no options does the initial build with these actions:"
  echo "    - Links clang and lld repos in $MLCC_LLVM_REPO_NAME/tools for a full build."
  echo "    - mkdir -p $MLCC_BUILD_DIR/llvm "
  echo "    - cd $MLCC_BUILD_DIR/llvm"
  echo "    - cmake $BUILD_DIR/$MLCC_LLVM_REPO_NAME (with cmake options below)"
  echo "    - make"
  echo
  echo " Optional Arguments 'nocmake' and 'install' :"
  echo "    build_llvm.sh takes one optional argument: 'nocmake' or 'install'. "
  echo "    The 'nocmake' or 'install' options can only be used after your initial build"
  echo "    with no options. The 'nocmake' option is intended to restart make after "
  echo "    you fix code following a failed build. The 'install' option will run 'make' "
  echo "    and 'make install' causing installation into the directorey $INSTALL_DIR . "
  echo "    The 'install' option will also create a symbolic link to directory $MLCC ."
  echo
  echo "    COMMAND                   ACTIONS"
  echo "    -------                   -------"
  echo "    ./build_llvm.sh nocmake   make"
  echo "    ./build_llvm.sh install   make install"
  echo
  echo " Environment Variables:"
  echo "    You can set environment variables to override behavior of build_llvm.sh"
  echo "    NAME              DEFAULT                  DESCRIPTION"
  echo "    ----              -------                  -----------"
  echo "    MLCC              /usr/local/mlcc           Where the compiler will be installed"
  echo "    MLCC_REPOS        $MLCC_REPOS    Location of llvm, clang, lld, and hcc2 repos"
  echo "    MLCC_CLANG_REPO_NAME   clang                    Name of the clang repo"
  echo "    MLCC_LLVM_REPO_NAME    llvm                     Name of the llvm repo"
  echo "    MLCC_LLD_REPO_NAME     lld                      Name of the lld repo"
  echo "    MLCC_LLVM_REPO_BRANCH   $MLCC_LLVM_REPO_BRANCH  The branch for llvm"
  echo "    MLCC_CLANG_REPO_BRANCH   $MLCC_CLANG_REPO_BRANCH  The branch for clang"
  echo "    MLCC_LLD_REPO_BRANCH   $MLCC_LLD_REPO_BRANCH  The branch for lld"
  echo "    SUDO              set                      Use sudo when installing"
  echo "    BUILD_TYPE        Release                  The CMAKE build type"
  echo "    MLCC_BUILD_DIR    MLCC_REPOS/build       Different build location than MLCC_REPOS"
  echo "    INSTALL_MLCC      <MLCC>_${MLCC_VERSION_STRING}             Different install location than <MLCC>_${MLCC_VERSION_STRING}"
  echo
  echo "   Since install typically requires sudo authority, the default for SUOO is 'set'"
  echo "   Any other value will not use sudo to install. "
  echo
  echo " Examples:"
  echo "    To build a debug version of the compiler, run this command before the build:"
  echo "       export BUILD_TYPE=Debug"
  echo "    To install the compiler in a different location without sudo, run these commands"
  echo "       export MLCC=$HOME/install/mlcc "
  echo "       export SUDO=no"
  echo
  echo " Post-Install Requirements:"
  echo "    The MLCC compiler needs openmp, hip, and rocm device libraries. Use the companion build"
  echo "    scripts build_openmp.sh, build_libdevice.sh build_hiprt.sh in that order to build and"
  echo "    install these components. You must have successfully built and installed the compiler"
  echo "    before building these components."
  echo
  echo " The MLCC_BUILD_DIR Envronment Variable:"
  echo
  echo "    build_llvm.sh will always build with cmake and make outside your source git trees."
  echo "    By default (without MLCC_BUILD_DIR) the build will occur in a subdirectory of"
  echo "    MLCC_REPOS.  That subdirectory is $MLCC_REPOS/build/llvm"
  echo
  echo "    The MLCC_BUILD_DIR environment variable enables source development outside your git"
  echo "    repositories. By default, this feature is OFF.  The MLCC_BUILD_DIR environment variable "
  echo "    can be used if access to your git repositories is very slow or you want to test "
  echo "    changes outside of your local git repositories (specified by MLCC_REPOS env var). "
  echo "    If MLCC_BUILD_DIR is set, your git repositories (specifed by MLCC_REPOS) will be"
  echo "    replicated to subdirectories of MLCC_BUILD_DIR using rsync.  The subsequent build "
  echo "    (cmake and make) will occur in subdirectory MLCC_BUILD_DIR/llvm."
  echo "    This replication only happens on your initial build, that is, if you specify no arguments."
  echo "    The option 'nocmake' skips replication and then restarts make in the build directory."
  echo "    The "install" option skips replication, skips cmake, runs 'make' and 'make install'. "
  echo "    Be careful to always use options nocmake or install if you made local changes in"
  echo "    MLCC_BUILD_DIR or your changes will be lost by a new replica of your git repositories."
  echo
  echo " cmake Options In Effect:"

  exit 
fi

if [ ! -L $MLCC ] ; then 
  if [ -d $MLCC ] ; then 
     echo "ERROR: Directory $MLCC is a physical directory."
     echo "       It must be a symbolic link or not exist"
     exit 1
  fi
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
}

# TODO schi we don't need checkrepo for now
# REPO_BRANCH=$MLCC_LLVM_REPO_BRANCH
# REPO_DIR=$MLCC_REPOS/$MLCC_LLVM_REPO_NAME
# checkrepo
# REPO_BRANCH=$MLCC_CLANG_REPO_BRANCH
# REPO_DIR=$MLCC_REPOS/$MLCC_CLANG_REPO_NAME
# checkrepo
# REPO_BRANCH=$MLCC_LLD_REPO_BRANCH
# REPO_DIR=$MLCC_REPOS/$MLCC_LLD_REPO_NAME
# checkrepo

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

# Fix the banner to print the MLCC version string. 
cd $MLCC_REPOS/$MLCC_LLVM_REPO_NAME
LLVMID=`git log | grep -m1 commit | cut -d" " -f2`
cd $MLCC_REPOS/$MLCC_CLANG_REPO_NAME
CLANGID=`git log | grep -m1 commit | cut -d" " -f2`
cd $MLCC_REPOS/$MLCC_LLD_REPO_NAME
LLDID=`git log | grep -m1 commit | cut -d" " -f2`
SOURCEID="Source ID:$MLCC_VERSION_STRING-$MLCC_LLVMID-$CLANGID-$LLDID"
TEMPCLFILE="/tmp/clfile$$.cpp"
ORIGCLFILE="$MLCC_REPOS/$MLCC_LLVM_REPO_NAME/lib/Support/CommandLine.cpp"
BUILDCLFILE="$BUILD_DIR/$MLCC_LLVM_REPO_NAME/lib/Support/CommandLine.cpp"
sed "s/LLVM (http:\/\/llvm\.org\/):/MLCC-${MLCC_VERSION_STRING} ($WEBSITE):\\\n $SOURCEID/" $ORIGCLFILE > $TEMPCLFILE
if [ $? != 0 ] ; then 
   echo "ERROR sed command to fix CommandLine.cpp failed."
   exit 1
fi

# Calculate the number of threads to use for make
NUM_THREADS=
if [ ! -z `which "getconf"` ]; then
   NUM_THREADS=$(`which "getconf"` _NPROCESSORS_ONLN)
   NUM_THREADS=$(( NUM_THREADS / 2))
   if [ "$PROC" == "ppc64le" ] ; then
      NUM_THREADS=$(( NUM_THREADS / 2))
   fi
fi

# Skip synchronization from git repos if nocmake or install are specified
if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then
   echo 
   echo "This is a FRESH START. ERASING any previous builds in $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME"
   echo "Use ""$0 nocmake"" or ""$0 install"" to avoid FRESH START."
   rm -rf $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME
   mkdir -p $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME

   if [ $COPYSOURCE ] ; then 
      #  Copy/rsync the git repos into /tmp for faster compilation
      mkdir -p $BUILD_DIR
      echo
      echo "WARNING!  BUILD_DIR($BUILD_DIR) != MLCC_REPOS($MLCC_REPOS)"
      echo "SO RSYNCING MLCC_REPOS TO: $BUILD_DIR"
      echo
      echo rsync -a --exclude ".git" --exclude "CommandLine.cpp" --delete $MLCC_REPOS/$MLCC_LLVM_REPO_NAME $BUILD_DIR 2>&1 
      rsync -av --exclude ".git" --exclude "CommandLine.cpp" --delete $MLCC_REPOS/$MLCC_LLVM_REPO_NAME $BUILD_DIR 2>&1 
      echo rsync -a --exclude ".git" --delete $MLCC_REPOS/$MLCC_CLANG_REPO_NAME $BUILD_DIR
      rsync -av --exclude ".git" --delete $MLCC_REPOS/$MLCC_CLANG_REPO_NAME $BUILD_DIR 2>&1 
      echo rsync -a --exclude ".git" --delete $MLCC_REPOS/$MLCC_LLD_REPO_NAME $BUILD_DIR
      rsync -av --exclude ".git" --delete $MLCC_REPOS/$MLCC_LLD_REPO_NAME $BUILD_DIR 2>&1

      mkdir -p $BUILD_DIR/$MLCC_LLVM_REPO_NAMEE/tools
      if [ -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/clang ] ; then 
        rm $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/clang
      fi
      ln -sf $BUILD_DIR/$MLCC_CLANG_REPO_NAME $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/clang
      if [ $? != 0 ] ; then 
         echo "ERROR link command for $MLCC_CLANG_REPO_NAME to clang failed."
         exit 1
      fi
      #  Remove old ld link, now using lld
      if [ -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/ld ] ; then
         rm $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/ld
      fi
      if [ -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/lld ] ; then
        rm $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/lld
      fi
      ln -sf $BUILD_DIR/$MLCC_LLD_REPO_NAME $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/lld
      if [ $? != 0 ] ; then
         echo "ERROR link command for $MLCC_LLD_REPO_NAME to lld failed."
         exit 1
      fi

   else
      cd $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools
      rm -f $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/clang
      if [ ! -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/clang ] ; then
         echo ln -sf $BUILD_DIR/$MLCC_CLANG_REPO_NAME clang
         ln -sf $BUILD_DIR/$MLCC_CLANG_REPO_NAME clang
      fi
      #  Remove old ld link, now using lld
      if [ -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/ld ] ; then
         rm $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/ld
      fi
      if [ ! -L $BUILD_DIR/$MLCC_LLVM_REPO_NAME/tools/lld ] ; then
         echo ln -sf $BUILD_DIR/$MLCC_LLD_REPO_NAME lld
         ln -sf $BUILD_DIR/$MLCC_LLD_REPO_NAME lld
      fi
   fi

else
   if [ ! -d $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME ] ; then 
      echo "ERROR: The build directory $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME does not exist"
      echo "       run $0 without nocmake or install options. " 
      exit 1
   fi
fi

cd $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME

if [ -f $BUILDCLFILE ] ; then 
   # only copy if there has been a change to the source.  
   diff $TEMPCLFILE $BUILDCLFILE >/dev/null
   if [ $? != 0 ] ; then 
      echo "Updating $BUILDCLFILE with corrected $SOURCEID"
      cp $TEMPCLFILE $BUILDCLFILE
   else 
      echo "File $BUILDCLFILE already has correct $SOURCEID"
   fi
else
   echo "Updating $BUILDCLFILE with $SOURCEID"
   cp $TEMPCLFILE $BUILDCLFILE
fi
rm $TEMPCLFILE

cd $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME

if [ "$1" != "nocmake" ] && [ "$1" != "install" ] ; then
   echo
   echo " -----Running cmake ---- " 
   echo cmake $MYCMAKEOPTS  $BUILD_DIR/$MLCC_LLVM_REPO_NAME
   cmake $MYCMAKEOPTS  $BUILD_DIR/$MLCC_LLVM_REPO_NAME 2>&1
   if [ $? != 0 ] ; then 
      echo "ERROR cmake failed. Cmake flags"
      echo "      $MYCMAKEOPTS"
      exit 1
   fi
fi

echo
echo " -----Running make ---- " 
echo make -j $NUM_THREADS 
#make -j $NUM_THREADS 
make
if [ $? != 0 ] ; then 
   echo "ERROR make -j $NUM_THREADS failed"
   exit 1
fi

if [ "$1" == "install" ] ; then
   echo " -----Installing to $INSTALL_DIR ---- " 
   $SUDO make install 
   if [ $? != 0 ] ; then 
      echo "ERROR make install failed "
      exit 1
   fi
   $SUDO make install/local
   if [ $? != 0 ] ; then 
      echo "ERROR make install/local failed "
      exit 1
   fi
   echo " "
   echo "------ Linking $INSTALL_DIR to $MLCC -------"
   if [ -L $MLCC ] ; then 
      $SUDO rm $MLCC   
   fi
   $SUDO ln -sf $INSTALL_DIR $MLCC   
   # add executables forgot by make install but needed for testing
   $SUDO cp -p $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME/bin/llvm-lit $MLCC/bin/llvm-lit
   $SUDO cp -p $MLCC_BUILD_DIR/$MLCC_LLVM_REPO_NAME/bin/FileCheck $MLCC/bin/FileCheck
   echo
   echo "SUCCESSFUL INSTALL to $INSTALL_DIR with link to $MLCC"
   echo
else 
   echo 
   echo "SUCCESSFUL BUILD, please run:  $0 install"
   echo "  to install into $MLCC"
   echo 
fi
