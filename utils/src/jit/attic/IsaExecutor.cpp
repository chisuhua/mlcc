// the Run function is a member fuction of RootFunc
//      the RootFunc is define in root_func.h which have varous ocl kernel builtin can be used
#include "utils/lang/types.h"
#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm/ExecutionEngine/Interpreter.h"
#include "llvm/ExecutionEngine/MCJIT.h"
#include "llvm/IR/Constants.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/Memory.h"
#include "llvm/Support/MemoryBuffer.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"

#include <map>
#include <string>
#include <vector>

#include "IsaExecutor.h"
#include "llvm_ir_kernel_loader.h"

std::once_flag llvm_initialized;

using namespace llvm;

class KernelJITManager {
public:
    KernelJITManager()
    {

        InitializeNativeTarget();
        InitializeNativeTargetAsmPrinter();
        InitializeNativeTargetAsmParser();
    }
    ~KernelJITManager()
    {
        // delete EE.get();
        // llvm_shutdown();
    }

    void compile(int* program, const std::string& kernel_name)
    {
        SMDiagnostic Err;

        //  kernel_code_t *kc = (kernel_code_t *)program;
        llvm_ir_kernel_loader kc_loader;
        bool is_llvm_ir = kc_loader.load_kernel((char*)program, kernel_loader::LOAD_FROM_MEM);

        // skip it is not llvm-ir bitcode
        program_map_.insert(std::make_pair(program, is_llvm_ir));
        if (!is_llvm_ir)
            return;

        // Load the bitcode...
        StringRef kc_buf(kc_loader.get_kernel_start_addr(), kc_loader.get_kernel_len());
        MemoryBufferRef bufRef(kc_buf, "bc");
        std::unique_ptr<Module> Owner = parseIR(bufRef, Err, Context, true, "");

        //get module
        Module* Mod = Owner.get();
        if (!Mod) {
            std::cout << "get module fail\n";
            return;
        }

        //create execution engine
        EngineBuilder builder(std::move(Owner));
        std::unique_ptr<ExecutionEngine> EE(builder.create());
        if (!EE) {
            std::cout << "unknown error creating EE!\n";
            return;
        }
        // Give MCJIT a chance to apply relocations and set page permissions.
        EE->finalizeObject();

        ee_map_.insert(std::make_pair(program, std::move(EE)));
    }

    void run(int* program, int* argument, int* private_mem, const std::string& kernel_name)
    {
        decltype(ee_map_)::iterator it = ee_map_.find(program);
        if (it == ee_map_.end()) {
            compile(program, kernel_name);
        }

        auto program_it = program_map_.find(program);
        assert(program_it != program_map_.end());

        if (program_it->second) {
            decltype(kernel_map_)::iterator kernel_it = kernel_map_.find(kernel_name);

            if (kernel_it == kernel_map_.end()) {
                auto& EE = (ee_map_.find(program))->second;
                /* configure global registers before execute kernel */
                /*
                std::string init_fn_name = "init_global_memory";
                Function* initFn = EE->FindFunctionNamed(init_fn_name.c_str());
                if (!initFn) {
                    std::cout
                        << " function not found in module, function name : "
                        << "\n";
                    assert(0);
                    return;
                }

                void* init_fn_ptr = EE->getPointerToFunction(initFn);
                assert(init_fn_ptr != nullptr);
                init_pfn = (void (*)(int*))(intptr_t)init_fn_ptr;
                */

                // std::string entry_name = "runKernel";
                /* start to execute kernel */
                Function* EntryFn = EE->FindFunctionNamed(kernel_name.c_str());
                if (!EntryFn) {
                    std::cout
                        << "Not an valid kernel format. \n"
                        << "Please convert to an valid format with the following command: \n"
                        << "${IXCC_PATH}/bin/opt -load &{IXCC_PATH}/lib/LLVMFuncWapper.so -FuncWapper src_file_name.bc -o dst_file_name.bc \n"
                        << "\n";
                    assert(0);
                    return;
                }

                void* fn_ptr = EE->getPointerToFunction(EntryFn);
                assert(fn_ptr != nullptr);
                pfn = (void (*)(int*, int*))(intptr_t)fn_ptr;

                // kernel_map_.insert(std::make_pair(kernel_name, std::make_pair(init_pfn, pfn)));
                kernel_map_.insert(std::make_pair(kernel_name, pfn));
                std::cout << "[LLVM_IR_ISA DEBUG]:\n"
                          << "      kerne_name:" << kernel_name << "\n"
                          << "      program:" << program << ", argument " << argument << "\n";
            } else {
                // init_pfn = (kernel_it->second).first;
                // pfn = (kernel_it->second).second;
                pfn = kernel_it->second;
            }
            // for debug only print
            // std::cout << "[LLVM_IR_ISA DEBUG]:  "
            //     << "      arg0:" << *(int*)(*(int64*)argument) << "\n";
            // init_pfn(private_mem);
            pfn(private_mem, argument);

        } else {
            pfn = (void (*)(int*, int*))(intptr_t)program;
            pfn(private_mem, argument);
        }
    }

    //    typedef void (*)(int *) FT_init_pfn;
    //    typedef void (*)(int *, int *) FT_pfn;

    // using FT_init_pfn = void (*)(int*);
    using FT_pfn = void (*)(int*, int*);

private:
    LLVMContext Context;
    void (*init_pfn)(int*);
    void (*pfn)(int*, int*);
    // std::map<int *, std::pair<void * , void *>> kernel_map_;
    // std::map<const std::string, std::pair<FT_init_pfn, FT_pfn>> kernel_map_;
    std::map<const std::string, FT_pfn> kernel_map_;
    std::map<int*, std::unique_ptr<ExecutionEngine>> ee_map_;

    // program_map will track it is llvm-ir bitcode or not for each program
    std::map<int*, bool> program_map_;
};

void isa_run_kernel(uint64* program, uint64* argument, int* private_mem, const std::string& kernel_name)
{
    static std::unique_ptr<KernelJITManager> jit_manager;

    std::call_once(llvm_initialized, []() {
        jit_manager = std::make_unique<KernelJITManager>();
    });

    jit_manager->run((int*)program, (int*)argument, (int*)private_mem, kernel_name);
}

/*
 * try to run kernel(*.bc)
 */
#ifdef USE_OLD_RUN_KERNEL
void isa_run_kernel(uint64* program, uint64* argument, int* private_mem)
{
    InitializeNativeTarget();
    InitializeNativeTargetAsmPrinter();
    InitializeNativeTargetAsmParser();

    LLVMContext Context;
    SMDiagnostic Err;

    //  kernel_code_t *kc = (kernel_code_t *)program;
    llvm_ir_kernel_loader kc_loader;
    kc_loader.load_kernel((char*)program, kernel_loader::LOAD_FROM_MEM);
    // Load the bitcode...
    StringRef kc_buf(kc_loader.get_kernel_start_addr(), kc_loader.get_kernel_len());
    MemoryBufferRef bufRef(kc_buf, "bc");
    std::unique_ptr<Module> Owner = parseIR(bufRef, Err, Context, true, "");

    //get module
    Module* Mod = Owner.get();
    if (!Mod) {
        std::cout << "get module fail\n";
        return;
    }

    //create execution engine
    EngineBuilder builder(std::move(Owner));
    std::unique_ptr<ExecutionEngine> EE(builder.create());
    if (!EE) {
        std::cout << "unknown error creating EE!\n";
        return;
    }

    // Give MCJIT a chance to apply relocations and set page permissions.
    EE->finalizeObject();

    /* configure global registers before execute kernel */
    std::string init_fn_name = "init_private_memory";
    StringRef initFunc(init_fn_name);
    Function* initFn = Mod->getFunction(initFunc);
    if (!initFn) {
        std::cout
            << " function not found in module, function name : "
            << "\n";
        return;
    }

    void* init_fn_ptr = EE->getPointerToFunction(initFn);
    if (!init_fn_ptr) {
        return;
    }

    void (*init_pfn)(int*) = (void (*)(int*))(intptr_t)init_fn_ptr;
    init_pfn(private_mem);

    /*
  * a tools called FuncWapper will add an wapper function "runKernel".
  * And "runKernel" has the following format:
  * void runKernel(uint8_t *program, uint8_t *kargs);
  * And runKernel will be responsiable for calling the real kernel.
  */
    std::string entry_name = "runKernel";
    /* start to execute kernel */
    StringRef EntryFunc(entry_name);
    Function* EntryFn = Mod->getFunction(EntryFunc);
    if (!EntryFn) {
        std::cout
            << "Not an valid kernel format. \n"
            << "Please convert to an valid format with the following command: \n"
            << "${IXCC_PATH}/bin/opt -load &{IXCC_PATH}/lib/LLVMFuncWapper.so -FuncWapper src_file_name.bc -o dst_file_name.bc \n"
            << "\n";
        return;
    }

    void* fn_ptr = EE->getPointerToFunction(EntryFn);
    if (!fn_ptr) {
        return;
    }
    void (*pfn)(int*, int*) = (void (*)(int*, int*))(intptr_t)fn_ptr;
    pfn((int*)program, (int*)argument);

    //  kernel_arg_t *karg = (kernel_arg_t *)argument;
    //  std::cout << "copy : " << karg->out[0] << ", " << karg->out[1] << ", " << karg->out[2] << "\n";
    return;
}
#endif
