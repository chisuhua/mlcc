#!/bin/bash
#
#  cloc.sh: Compile cl file into an HSA Code object file (.hsaco)
#           using the LLVM Ligntning Compiler. An hsaco file contains
#           the amdgpu isa that can be loaded by the HSA Runtime.
#
#
PROGVERSION="X.Y-Z"
#
#
function usage(){
/bin/cat 2>&1 <<"EOF"

   cloc.sh: Compile a cl or cu file into an HSA Code object file (.hsaco)
            using the MLCC compiler. An hsaco file contains the amdgpu
            isa that can be loaded by the HSA Runtime.
            The creation of hsaco for cuda kernels is experimental.

   Usage: cloc.sh [ options ] filename.cl

   Options without values:
    -ll       Generate IR for LLVM steps before generating hsaco
    -s        Generate dissassembled gcn from hsaco
    -g        Generate debug information
    -noqp     No quickpath, Use LLVM commands instead of clang driver
    -noshared Do not link hsaco as shared object, forces noqp
    -version  Display version of cloc then exit
    -v        Verbose messages
    -n        Dryrun, do nothing, show commands that would execute
    -h        Print this help message
    -k        Keep temporary files

   Options with values:
    -mlcc      <path>           $MLCC or /usr/local/mlcc
    -libgcn    <path>           $DEVICELIB or $MLCC/lib/libdevice
    -cuda-path <path>           $CUDA_PATH or /usr/local/cuda
    -atmipath  <path>           $ATMI_PATH or /opt/rocm/hcc2
    -mcpu      <cputype>        Default= value returned by mygpu
    -bclib     <bcfile>         Add a bc library for llvm-link
    -clopts    <compiler opts>  Addtional options for cl frontend
    -cuopts    <compiler opts>  Additonal options for cu frontend
    -I         <include dir>    Provide one directory per -I option
    -opt       <LLVM opt>       LLVM optimization level
    -o         <outfilename>    Default=<filename>.<ft> ft=hsaco
    -t         <tdir>           Temporary directory or intermediate files
                                Default=/tmp/cloc-tmp-$$
   Examples:
    cloc.sh my.cl             /* creates my.hsaco                    */
    cloc.sh whybother.cu      /* creates whybother.hsaco             */

   Note: Instead of providing these command line options:
     -hcc2, -libgcn, -cuda-path, -atmipath -mcpu, -clopts, or -cuopts
     you may set these environment variables, respectively:
     MLCC, DEVICELIB, CUDA_PATH, ATMI_PATH, LC_MCPU, CLOPTS, or CUOPTS

   Command line options will take precedence over environment variables.
EOF
   exit 0
}

THIS_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MLCC=$THIS_SCRIPT_DIR/..
# TODO hack
#IXCC_HACK=/work/opt/git_rocm/hcc2
#IXCC_HACK=$MLCC

DEADRC=12

#  Utility Functions
function do_err(){
   if [ $NEWTMPDIR ] ; then
      if [ $KEEPTDIR ] ; then
         cp -rp $TMPDIR $OUTDIR
         [ $VERBOSE ] && echo "#Info:  Temp files copied to $OUTDIR/$TMPNAME"
      fi
      rm -rf $TMPDIR
   else
      if [ $KEEPTDIR ] ; then
         [ $VERBOSE ] && echo "#Info:  Temp files kept in $TMPDIR"
      fi
   fi
   [ $VERBOSE ] && echo "#Info:  Done"
   exit $1
}

function version(){
   echo $PROGVERSION
   exit 0
}

function runcmd(){
   THISCMD=$1
   if [ $DRYRUN ] ; then
      echo "$THISCMD"
   else
      [ $VV ] && echo "$THISCMD"
      $THISCMD
      rc=$?
      if [ $rc != 0 ] ; then
         echo "ERROR:  The following command failed with return code $rc."
         echo "        $THISCMD"
         do_err $rc
      fi
   fi
}

function getdname(){
   _DIR="$( cd "$( dirname "$1" )" && pwd )"
   echo $_DIR
}

#  --------  The main code starts here -----
INCLUDES=""
#  Argument processing
while [ $# -gt 0 ] ; do
   case "$1" in
      -q)               QUIET=true;;
      --quiet)          QUIET=true;;
      -k) 		KEEPTDIR=true;;
      -n) 		DRYRUN=true;;
      -hsail) 		GEN_IL=true;;
      -brig) 		GEN_BRIG=true;;
      -g) 		GEN_DEBUG=true;;
      -ll) 		GENLL=true;;
      -s) 		GENASM=true;;
      -noqp) 		NOQP=true;;
      -noshared) 	NOSHARED=true;;
      -clopts) 		CLOPTS=$2; shift ;;
      -cuopts) 		CUOPTS=$2; shift ;;
      -I) 		INCLUDES="$INCLUDES -I $2"; shift ;;
      -opt) 		LLVMOPT=$2; shift ;;
      -o) 		OUTFILE=$2; shift ;;
      -t)		TMPDIR=$2; shift ;;
      -bclib)		EXTRABCLIB=$2; shift ;;
      -mcpu)            LC_MCPU=$2; shift ;;
      -mlcc)            MLCC=$2; shift ;;
      -triple)          TARGET_TRIPLE=$2; shift ;;
      -libgcn)          DEVICELIB=$2; shift ;;
      -atmipath)        ATMI_PATH=$2; shift ;;
      -cuda-path)       CUDA_PATH=$2; shift ;;
      -h) 	        usage ;;
      -help) 	        usage ;;
      --help) 	        usage ;;
      -version) 	version ;;
      --version) 	version ;;
      -v) 		VERBOSE=true;;
      -vv) 		VV=true;;
      --) 		shift ; break;;
      *) 		break;echo $1 ignored;
   esac
   shift
done

# The above while loop is exited when last string with a "-" is processed
LASTARG=$1
shift

#  Allow output specifier after the cl file
if [ "$1" == "-o" ]; then
   OUTFILE=$2; shift ; shift;
fi

if [ ! -z $1 ]; then
   echo " "
   echo "WARNING:  cloc.sh can only process one .cl or .cu file at a time."
   echo "          You can call cloc multiple times to get multiple outputs."
   echo "          Argument $LASTARG will be processed. "
   echo "          These args are ignored: $@"
   echo " "
fi

cdir=$(getdname $0)
[ ! -L "$cdir/cloc.sh" ] || cdir=$(getdname `readlink "$cdir/cloc.sh"`)

MLCC=${MLCC:-/usr/local/mlcc}
DEVICELIB=${DEVICELIB:-$MLCC/lib/libdevice}
TARGET_TRIPLE=${TARGET_TRIPLE:-amdgcn-amd-amdhsa}
CUDA_PATH=${CUDA_PATH:-/usr/local/cuda}
ATMI_PATH=${ATMI_PATH:-/opt/rocm/hcc2}

# Determine which gfx processor to use, default to Tahiti(gfx600) not (Fiji (gfx803)
if [ ! $LC_MCPU ] ; then
   # Use the mygpu in pair with this script, no the pre-installed one.
   #LC_MCPU=`$cdir/mygpu`
   #if [ "$LC_MCPU" == "" ] ; then
   #   LC_MCPU="gfx600"
   #fi
   ## TODO schi hard code for pasim
   LC_MCPU="gfx600"
fi

LLVMOPT=${LLVMOPT:-2}

# TODO schi 
#CUOPTS=${CUOPTS:- -fcuda-rdc --cuda-device-only -Wno-unused-value --hip-auto-headers=cuda_open -O$LLVMOPT --cuda-gpu-arch=$LC_MCPU}
 CUOPTS=${CUOPTS:- -fgpu-rdc --cuda-device-only -Wno-unused-value --hip-auto-headers=cuda_open -O$LLVMOPT --cuda-gpu-arch=$LC_MCPU}
#CUOPTS=${CUOPTS:- -fcuda-rdc --cuda-device-only -Wno-unused-value --cuda-gpu-arch=$LC_MCPU --hip-device-lib-path=$cdir/../lib/libdevice/$LC_MCPU --no-cuda-version-check -nocudalib -O$LLVMOPT}

if [ $VV ]  ; then
   VERBOSE=true
fi

BCFILES=""

# Check if user supplied libgcn has libdevice convention
GCNDEVICE=`echo $DEVICELIB | grep libdevice`

if [ -z $GCNDEVICE ]; then
  # Here a User supplied libgcn does not have libdevice convention
  DEVICELIBDIR=$DEVICELIB
else
  # This is the default path. bc files are found with libdevice convention
  # $MLCC/lib/libdevice/$LC-MCPU/
  DEVICELIBDIR=$DEVICELIB/$LC_MCPU
fi

BCFILES="$BCFILES $DEVICELIBDIR/cuda2gcn.amdgcn.bc"
# this bc create in seperae script
# BCFILES="$BCFILES $DEVICELIBDIR/cuda2pasim.pasim.bc"
BCFILES="$BCFILES $DEVICELIBDIR/hip.amdgcn.bc"
BCFILES="$BCFILES $DEVICELIBDIR/hc.amdgcn.bc"
BCFILES="$BCFILES $DEVICELIBDIR/opencl.amdgcn.bc"
BCFILES="$BCFILES $DEVICELIBDIR/ocml.amdgcn.bc"
BCFILES="$BCFILES $DEVICELIBDIR/ockl.amdgcn.bc"
BCFILES="$BCFILES $DEVICELIBDIR/oclc_isa_version.amdgcn.bc"
if [ -f $ATMI_PATH/lib/libdevice/$LC_MCPU/libatmi.bc ]; then
    BCFILES="$BCFILES $ATMI_PATH/lib/libdevice/$LC_MCPU/libatmi.bc"
else
  if [ -f $DEVICELIBDIR/libatmi.bc ]; then
    BCFILES="$BCFILES $DEVICELIBDIR/libatmi.bc"
  fi
fi

if [ $EXTRABCLIB ] ; then
   if [ -f $EXTRABCLIB ] ; then
#     EXTRABCFILE will force QP off so LINKOPTS not used.
      BCFILES="$EXTRABCLIB $BCFILES"
   else
      echo "ERROR: Environment variable EXTRABCLIB is set to $EXTRABCLIB"
      echo "       File $EXTRABCLIB does not exist"
      exit $DEADRC
   fi
fi

filetype=${LASTARG##*\.}
if [ "$filetype" != "cl" ]  ; then
   if [ "$filetype" != "cu" ] ; then
      echo "ERROR:  $0 requires one argument with file type cl or cu"
      exit $DEADRC
   else
      CUDACLANG=true
      if [ ! -d $CUDA_PATH ] ; then
         echo "ERROR:  No CUDA_PATH directory at $CUDA_PATH "
         exit $DEADRC
      fi
   fi
fi

#  Define the subcomands
if [ $CUDACLANG ] ; then
   INCLUDES="-I $CUDA_PATH/include ${INCLUDES}"
   CMD_CLC=${CMD_CLC:-clang++ $CUOPTS $INCLUDES}
else
  if [ -z $GCNDEVICE ]; then
    INCLUDES="-I ${DEVICELIB}/include ${INCLUDES}"
  else
    INCLUDES="-I ${DEVICELIB}/$LC_MCPU/include ${INCLUDES}"
  fi
  CMD_CLC=${CMD_CLC:-clang -x cl -Xclang -cl-std=CL2.0 $CLOPTS $LINKOPTS $INCLUDES -include opencl-c.h -Dcl_clang_storage_class_specifiers -Dcl_khr_fp64 -target ${TARGET_TRIPLE}}
fi
CMD_LLA=${CMD_LLA:-llvm-dis}
CMD_ASM=${CMD_ASM:-llvm-as}
CMD_LLL=${CMD_LLL:-llvm-link}
CMD_OPT=${CMD_OPT:-opt -O$LLVMOPT -mcpu=$LC_MCPU -amdgpu-annotate-kernel-features}
CMD_LLC=${CMD_LLC:-$MLCC/bin/llc -mtriple ${TARGET_TRIPLE} -mcpu=$LC_MCPU -filetype=obj}

RUNDATE=`date`

if [ ! -e "$LASTARG" ]  ; then
   echo "ERROR:  The file $LASTARG does not exist."
   exit $DEADRC
fi

# Parse LASTARG for directory, filename, and symbolname
INDIR=$(getdname $LASTARG)
FILENAME=${LASTARG##*/}
# FNAME has the .cl extension removed, used for naming intermediate filenames
FNAME=${FILENAME%.*}

if [ -z $OUTFILE ] ; then
#  Output file not specified so use input directory
   OUTDIR=$INDIR
#  Make up the output file name based on last step
   if [ $GEN_BRIG ] || [ $GEN_IL ] ; then
      OUTFILE=${FNAME}.brig
   else
      OUTFILE=${FNAME}.hsaco
   fi
else
#  Use the specified OUTFILE
   OUTDIR=$(getdname $OUTFILE)
   OUTFILE=${OUTFILE##*/}
fi

sdir=$(getdname $0)
[ ! -L "$sdir/cloc.sh" ] || sdir=$(getdname `readlink "$sdir/cloc.sh"`)
CLOC_PATH=${CLOC_PATH:-$sdir}

TMPNAME="cloc-tmp-$$"
TMPDIR=${TMPDIR:-/tmp/$TMPNAME}
if [ -d $TMPDIR ] ; then
   KEEPTDIR=true
else
   if [ $DRYRUN ] ; then
      echo "mkdir -p $TMPDIR"
   else
      mkdir -p $TMPDIR
      NEWTMPDIR=true
   fi
fi

# Be sure not to delete the output directory
if [ $TMPDIR == $OUTDIR ] ; then
   KEEPTDIR=true
fi
if [ ! -d $TMPDIR ] && [ ! $DRYRUN ] ; then
   echo "ERROR:  Directory $TMPDIR does not exist or could not be created"
   exit $DEADRC
fi
if [ ! -d $OUTDIR ] && [ ! $DRYRUN ]  ; then
   echo "ERROR:  The output directory $OUTDIR does not exist"
   exit $DEADRC
fi

#  Print Header block
if [ $VERBOSE ] ; then
   echo "#   "
   echo "#Info:  MLCC Version:	$PROGVERSION"
   echo "#Info:  MLCC Path:	$MLCC"
   echo "#Info:  Run date:	$RUNDATE"
   echo "#Info:  Input file:	$INDIR/$FILENAME"
   echo "#Info:  Code object:	$OUTDIR/$OUTFILE"
   [ $KEEPTDIR ] &&  echo "#Info:  Temp dir:	$TMPDIR"
   echo "#   "
fi

if [ $GEN_IL ] ||  [  $GEN_BRIG ] ; then
   echo "ERROR:  Support for HSAIL and BRIG generation depricated"
   exit $DEADRC
fi

rc=0

   if [ $VV ]  ; then
      CLOPTS="-v $CLOPTS"
   fi

   if [ $NOQP ] || [ $GENLL ] || [ $NOSHARED ] || [ $EXTRABCLIB ] ; then
      quickpath="false"
   else
      quickpath="true"
   fi
   #  Fixme :  need long path for linking multiple libs
   quickpath="false"

   if [ "$quickpath" == "true" ] ; then

      [ $VV ] && echo
      [ $VERBOSE ] && echo "#Step:  Compile cl	cl --> hsaco ..."
      runcmd "$MLCC/bin/$CMD_CLC -o $OUTDIR/$OUTFILE $INDIR/$FILENAME"

   else
      # Run 4 steps, clang,link,opt,llc
      if [ $CUDACLANG ] ; then
         [ $VV ] && echo
         [ $VERBOSE ] && echo "#Step:  cuda-clang	cu --> bc  ..."
         runcmd "$MLCC/bin/$CMD_CLC -o $TMPDIR/$FNAME.bc $INDIR/$FILENAME"
      else
         [ $VV ] && echo
         [ $VERBOSE ] && echo "#Step:  Compile cl	cl --> bc ..."
         runcmd "$MLCC/bin/$CMD_CLC -c -emit-llvm -o $TMPDIR/$FNAME.bc $INDIR/$FILENAME"
      fi

      if [ $GENLL ] ; then
         [ $VV ] && echo
         [ $VERBOSE ] && echo "#Step:  Disassemble	bc --> ll ..."
         runcmd "$MLCC/bin/$CMD_LLA -o $TMPDIR/$FNAME.ll $TMPDIR/$FNAME.bc"
         if [ "$OUTDIR" != "$TMPDIR" ] ; then
            runcmd "cp $TMPDIR/$FNAME.ll $OUTDIR/$FNAME.ll"
         fi
      fi

      [ $VV ] && echo
      [ $VERBOSE ] && echo "#Step:  Link(llvm-link)	bc --> lnkd.bc ..."
      runcmd "$MLCC/bin/$CMD_LLL $TMPDIR/$FNAME.bc $BCFILES -o $TMPDIR/$FNAME.lnkd.bc"

      if [ $GENLL ] ; then
         [ $VV ] && echo
         [ $VERBOSE ] && echo "#Step:  Disassemble	lnkd.bc --> lnkd.ll ..."
         runcmd "$MLCC/bin/$CMD_LLA -o $TMPDIR/$FNAME.lnkd.ll $TMPDIR/$FNAME.lnkd.bc"
         if [ "$OUTDIR" != "$TMPDIR" ] ; then
            runcmd "cp $TMPDIR/$FNAME.lnkd.ll $OUTDIR/$FNAME.lnkd.ll"
         fi
      fi

      if [ $LLVMOPT != 0 ] ; then
         [ $VV ] && echo
         [ $VERBOSE ] && echo "#Step:  Optimize(opt)	lnkd.bc --> final.bc -O$LLVMOPT ..."
         runcmd "$MLCC/bin/$CMD_OPT -o $TMPDIR/$FNAME.final.bc $TMPDIR/$FNAME.lnkd.bc"

         if [ $GENLL ] ; then
            [ $VV ] && echo
            [ $VERBOSE ] && echo "#Step:  Disassemble	final.bc --> final.ll ..."
            runcmd "$MLCC/bin/$CMD_LLA -o $TMPDIR/$FNAME.final.ll $TMPDIR/$FNAME.final.bc"
            if [ "$OUTDIR" != "$TMPDIR" ] ; then
               runcmd "cp $TMPDIR/$FNAME.final.ll $OUTDIR/$FNAME.final.ll"
            fi
         fi
         LLC_BC="final"
      else
         # No optimization so generate object for lnkd bc.
         LLC_BC="lnkd"
      fi

      [ $VV ] && echo
      [ $VERBOSE ] && echo "#Step:  llc mcpu=$LC_MCPU	$LLC_BC.bc --> amdgcn ..."
      runcmd "$CMD_LLC -o $TMPDIR/$FNAME.gcn $TMPDIR/$FNAME.$LLC_BC.bc"
      runcmd "cp $TMPDIR/$FNAME.$LLC_BC.bc $OUTDIR"

      [ $VV ] && echo
      [ $VERBOSE ] && echo "#Step:	ld.lld		gcn --> hsaco ..."
      if [ $NOSHARED ] ; then
           SHAREDARG=""
      else
           SHAREDARG="-shared"
      fi
      #  FIXME:  Why does shared sometimes cause the -fPIC problem ?
      runcmd "$MLCC/bin/ld.lld $TMPDIR/$FNAME.gcn --no-undefined $SHAREDARG -o $OUTDIR/$OUTFILE"


   fi # end of if quickpath then ... else  ...

   if [ $GENASM ] ; then
      [ $VV ] && echo
      [ $VERBOSE ] && echo "#Step:  llvm-objdump 	hsaco --> .s ..."
      textstarthex=`readelf -S -W  $OUTDIR/$OUTFILE | grep .text | awk '{print $6}'`
      textstart=$((0x$textstarthex))
      textszhex=`readelf -S -W $OUTDIR/$OUTFILE | grep .text | awk '{print $7}'`
      textsz=$((0x$textszhex))
      countclause=" count=$textsz skip=$textstart"
      dd if=$OUTDIR/$OUTFILE of=$OUTDIR/$FNAME.raw bs=1 $countclause 2>/dev/null
      hexdump -v -e '/1 "0x%02X "' $OUTDIR/$FNAME.raw | $MLCC/bin/llvm-mc -arch=amdgcn -mcpu=$LC_MCPU -disassemble >$OUTDIR/$FNAME.s 2>$OUTDIR/$FNAME.s.err
      rm $OUTDIR/$FNAME.raw
      if [ "$LC_MCPU" == "kaveri" ] ; then
         echo "WARNING:  Disassembly not supported for Kaveri. See $FNAME.s.err"
      else
         rm $OUTDIR/$FNAME.s.err
         echo "#INFO File $OUTDIR/$FNAME.s contains amdgcn assembly"
      fi
   fi

# cleanup
do_err 0
exit 0
