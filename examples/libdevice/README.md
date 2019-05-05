This directory contains examples of the creation of a Device BitCode Library
(DBCL).  A DBCL is used in a new proposed methodlogy for OpenMP device library
linking.  Here is a text version of a paper under develoment that explains
the proposed methodlogy for device library linking.  Currently this directory
only contains one DBCL for libm.  In this example, platform specific bc files
are created for both nvptx and amdgcn architectures.

We also plan to add an example of how to build a static library for devices. 
This will need some tool improvements and possibly clang improvements.
See NOTES below. 


OpenMP Device Library Linking for LLVM/Clang
============================================

Abstract
--------

Currently clang-CUDA and clang-HIP provide platform-specific device function definitions in header files that are compiled for every source module compilation.
We propose a device library methodology for clang-OpenMP that is consistent with host library management.
This methdology provides the option to compile platform-specific device functions into LLVM bitcode files called "Device BitCode Libraries" or DBCLs.
This eliminates the need to put platform-specific function definitions in header files.
Furthermore, it allows the use of traditional host library header files that only contain function declarations.
This methodology utilizes LLVM linking of application device code with DBCLs.
This early linking of DBCLs is done before backend ISA generation.
This allows for more complete inlining and optimizing of GPU kernels with LLVM optimization passes.
This methodology can optionally support future OpenMP 5.0 context-aware function variants and the ability to have debug versions of libraries.

DBCL Use Model
--------------

The use model for DBCLs is consistent with host libraries.
That is, the clang compiler accepts multiple -l command line options that trigger a library search.
The search process uses directories specified with -L and/or the value of the LIBRARY_PATH environment variable.
Since the user must already provide standard system headers for host function declarations, these same headers can be used for the device pass.
For example, if a user wants to use math functions, he will #include <math.h> for c or #include \<cmath\> for c++.
The user will continue to specify the -lm link option to trigger a search for libm.

The only change to the use model for DBCLs is a new capability to link to the DBCL
immediately following clang device compilation.
This "post-compile" linking is entirely optional.
It is also triggered by the -l option when the -l option is available as a compiler option as opposed to its use as a link option. 


DBCL Linking
------------

Changes to the clang driver toolchains are being tested as part of the HCC2 compiler to support device linking of DBCLs.
For each -l option, the clang driver will now search for platform-specific DBCLs.
This is done in addition to the traditional search and linking of archive (.a) and shared object (.so) files.
If it finds a DBCL it will use it in early linking of the LLVM IR.
There are two types of early linking of DBCLs.

The first type of early linking can occur during the device compile phase while the device LLVM IR is still in memory.
This is before the device backend or device assemble phase.
We call this "post-compile" early linking.
Post-compile early linking only occurs if the -l option is provided as a compile option.
If a DBCL file is found for the specified -l libray and the specified device architecture,
the clang driver will add a -mlink-builtin-bitcode option to the clang -cc1 device pass.
This is not an extra step, command, or phase by the clang driver.
The -mlink-builtin-bitcode option will cause clang to link the DBCL while the device LLVM IR is still in memory.
If specified, post-compile early linking will occur for each source module for each device pass.

The 2nd type of DBCL linking occurs during the application device link phase.
This type of linking can only occur when the OpenMP driver manages device object as LLVM IR.
That is, the device object is NOT device ISA binary such as cubin or hsaco.
The generation of device ISA is delayed to a single backend step after all device LLVM IRs are linked.
Currently, only the architecture that manages device object as LLVM IR is amdgcn. (CHECK THIS)
In this type of driver, there are no steps to the backend or assemble phase.
Therefore, the user specified -c option creates an object bundle (.o file) that contains
object code for host ISA and LLVM IR bitcode for each type of device.
In this type of driver, the device link phase contains many steps.

- First all the .o bundles (one for each source module) are unbundled to expose the device bitcode files.
- Then the device bitcode files are then linked together with any DBCL files found from a search of each -l option creating a single LLVM IR.
- Then LLVM optimization passes are applied to the single LLVM IR.
- Then the backend is called to generate device-specifiec ISA from the optimized LLVM IR.
- Then the device linker is called to link any platform-specfic ISA libraries not available as DBCLs.  For amdgcn, this device linker is LLVM lld. For nvptx,the ISA device linker is nvlink.
- After the final ISA binares are created (one per device type), the host linker includes these device binaries as images in an elf section as part of the final application binary. The libomptarget initialization runtime knows how to extract the correct image for the available device type.

Creating DBCLs
--------------

This section is provided for library developers who want to provide device versions of their libraries.  More details will be provided in the future.

The construction of the libm DBCL is provided as an example in the libm directory.
This has been tested with the experimental HCC2 compiler. 
In this example, we use clang++ and clang to compile cpp and c files respectively.
The Makefile uses the environment variable HCC2_GPU to drive the build. 
By default this is set to sm_60. Running the make command will create one DBCL in 

```
build/libdevice/sm_60/libm-nvptx-sm_60.bc
```

The simple script libm.sh will run make for various values of HCC2_GPU.

```
#  libm.sh
GPUS="gfx700 gfx701 gfx801 gfx803 gfx900 "
GPUS+="sm_30 sm_35 sm_50 sm_60"
for i in $GPUS ; do
  HCC2_GPU=$i make
done
```

The resulting DBCLs can be displayed with the following find command.

```
find build/libdevice -type f
build/libdevice/gfx701/libm-amdgcn-gfx701.bc
build/libdevice/gfx803/libm-amdgcn-gfx803.bc
build/libdevice/sm_50/libm-nvptx-sm_50.bc
build/libdevice/sm_30/libm-nvptx-sm_30.bc
build/libdevice/sm_60/libm-nvptx-sm_60.bc
build/libdevice/sm_35/libm-nvptx-sm_35.bc
build/libdevice/gfx900/libm-amdgcn-gfx900.bc
build/libdevice/gfx700/libm-amdgcn-gfx700.bc
build/libdevice/gfx801/libm-amdgcn-gfx801.bc
```

Intermediate files are written to the build directory. 
Currently, there is no device-only option for clang-openmp,
so the Makefile unbundles the .o and ignores the host object.
To better understand the Makefile all file names that are bundles have the 
string '.b.' embedded in the file name. 
The construction of the libm DBCLs compiles both c and c++ variants 
of the math functions.

The following source files are used to create libm DBCLs. 


```
libm.c  	Includes libm-amdgcn.c or libm-nvptx.c depending on device
libm.cpp	Includes libm-amdgcn.cpp or libm-nvptx.cpp depending on device
libm-amdgcn.c	c variants of math functions for amdgcn
libm-amdgcn.cpp	c++ variants of math functions for amdgcn
libm-amdgcn.h   amdgcn headers used by c and cpp, typically begin with __ocml_
libm-nvptx.c   	c variants of math functions for nvptx
libm-nvptx.cpp  c++ variants of math functions for nvptx
libm-nvptx.h	nvptx headers used by c and cpp, typically begin with __nv_
libm.sh 	Script to run make for many GPUs
Makefile        Makefile to compile libm.c 
```


The libdevice Naming Convention:
--------------------------------
As the use of OpenMP offloading grows, we expect a significant number of new
DBCL libraries. Multiply this by the number of potential device-types
(sm\_30, sm\_60, gfx802, gfx900, etc.) and then the number of potential variants
such as debug or special versions of the libraries (such reduced accuracy
or fast versions).  It is certainly possible to store these bc files in the
host linking subdirectory.  That is typically ../lib.  The platform specific
bc files in this directy must be differentiated in the file name with the
platform architecture name and the device-type.
The current convention used for omptarget bc libraries is:

```
   ../lib/libomptarget-<archname>-<devicetype>.bc
```

For example, the current omptarget bc file for nvida sm\_60 GPUs is typically
found at:

```
   ../lib/libomptarget-nvptx-sm_60.bc.
```

In order to better organize the large number of bc files expected, we propose
an extension to the current naming convention called the libdevice
naming convention.

Let's assume the the library name is X.  Then the compiler will first look
for libX-\<archname\>-\<devicetype\>.bc in the directory

```
   <LPATH>/libdevice/<devicetype>
```

If not found, the compiler will use the current convention and look for
libX-\<archname\>-\<devicetype\>.bc in the <LPATH> directory.  The directory \<LPATH\>
is first determined by the -L option, followed by directories specified by
LIBRARY_PATH environment variable, and lastly look in \<CLANG\_BIN\>/../lib
where \<CLANG\_BIN\> is the directory of the clang compiler executable.

Device Archive Linking
----------------------
The current clang driver in the trunk fails when a static library (.a) is used 
as input.  Clang thinks these files are object files.  When used as an input
for an OpenMP compile, the driver tries to unbundle the .a file. 
Changes are necessary to properly handle this. 


Library Components by filetype
------------------------------

```
.bc  "DBCL" file. DBCL=Device bc Library
     This is a bitcode file that is either GPU-specific, architecture-specific
     or non-specific.  It is typically GPU-specific. It is precompiled
     and available for use with the compiler or library distribution.
     The filename provides information about how specific is the file.
     libX.bc              is nonspecific
     libX-<arch>.bc       is architecture-specific
     libX-<arch>-<GPU>.bc is GPU-specific

.o  Object file.  An object file can either be a bundled object file
    or a traditional host object file. If it is an ELF file then it is
    a host object file, otherwise it is a bundled object file. 
    If it is a bundled object file, it may or may not contain host object.
    Device objects can be either LLVM bitcode or compiled device binary
    such as cubin or hsaco. If the device object is an ELF file, then it is 
    a compiled device binary, otherwise it is LLVM bitcode (bc).
    If the device object is bitcode, then the device object is input
    to early llvm-linking.  When extracting bc it is advisable to use the
    libdevice naming convention that contains the archname and devicetype.
  NOTE1:  We need a method to query a bundled .o file for a list 
    of device types and object types to aid in building the unbundle
    command. e.g. clang-offload-bundler -q <object file>
    -->  x86_64, gfx803-hsaco, gfx900-bc, sm_60-cubin.
  NOTE2:  We would like that the clang-offload-bundler tool be 
    smart enough to extract a specified set of devicetypes and not 
    all devicetypes stored in the object bundle.

.a  Static library.  A static library is an archive of object files. 
    Since an object file can be a bunlded oject or a traditional
    host object, a static library can be either an archive of
     host-only objects or an archive of bundled object files.
  NOTE3:  We need a method to query an archive of object bundles for all
    the device types. e.g. clang-offload-bundler -q <static library>
    -->  x86_64, gfx803-hsaco, gfx900-bc, sm_60-cubin.

.so Shared object files for host-only linking or dynamic linking.
```

Example of HOW to use DBCL:
---------------------------
Assume an openmp compile of foo.c and the target offload arch is sm_30.
We assume foo.c uses math functions by including math.h. 
The programmer must therefore compile with the -lm option . 
The abbreviated clang command would be something like this.  

```
   clang -fopenmp ... -march=sm_30 -lm foo.c -o foo
```

By reusing the -l option, there is nothing new about how external libraries
are specified to the compiler. Internally the clang driver will generate
commands when it finds DBCLs for the specified library and GPU. 
For example, if the GPU is sm_30 and the user specifies the -lm option, 
the following clang cc1 option will be generated IF a DBCL is found:

```
   <CLANG_BIN>/clang -cc1 \
   -mlink-builtin-bitcode=<LPATH>/libdevice/sm_30/libm-nvptx-sm_30.bc
```

where \<LPATH\> is \<CLANG\_BIN\>/../lib or a directory specified with the 
 -L option or the LIBRARY_PATH environment variable. The actual clang
 -cc1 command for a device pass has many other options not shown above. 

Host-Only Libraries:
--------------------

Many user codes will have header files and corresponding -l link options
where there is no device library or a device library has not yet been
implemented. The classic example of this is mpi. What will happen for
host-only libraries?  That is, the user code has #include \<mpi.h\>
and -lmpi was specified on the command line?

There are two scenarios:

```
1. The users device code does not use mpi functions. There should be
   no warning or error messages. The driver will see the -lmpi and
   look for libmpi-<arch>-<gpu>.bc while constructing the device
   clang cc1 pass.  It will not find a DBCL and thus no option for
   -mlink-builtin-bitcode will be generated. No warning message should
   be generated for the use of the -lmpi option by the user.

2. The user code accidentally uses an mpi function in their
   device code.  Where will there be warnings and where will be
   the error generated?  There will be no driver or device pass
   warning or error message. The error will occur late in the
   device link phase after ISA code generation.
```

FAQ:
----

```
Q: What happens when a user code uses a function in a library that is 
   only available on a certain GPU?  Example: fast_sqrt().  
A: The library implementor should surround the implementation with 
   the particulare macro ifdef for that GPU.  For nvptx they use
   __NVPTX__ .  For amdgcn, use __AMDGCN__.
   #ifdef  __AMDGCN__  && ( __AMDGCN__ == 1000 )
   double fast_sqrt(double __a) { ... }
   #endif
   The user will get a GPU link failure (ldd on amdgcn, nvlink for nvidia)
   when he uses fast_sqrt. 
   A clever implementor would provide an alternative slow version
   for other GPUs. 
   #ifdef  __AMDGCN__  && ( __AMDGCN__ == 1000 )
   double fast_sqrt(double __a) { ... };
   #else
   #warning fast_sqrt not available on this platform, using sqrt.  
   double fast_sqrt(double __a) { sqrt(__a) };
   #endif
   This strategy encourages soft implementations that promote 
   portability. 

```
