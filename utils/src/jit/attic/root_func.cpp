#include <memory>
#include "aasim/root_func.h"

#include "utils/lang/types.h"
#include <cerrno>
#include <iostream>
#include <fstream>
#include <string>
#include "asim/Simulator.h"
#include "asim/ComputeCore.h"


extern void isa_run_kernel(uint64* program, uint64* argument, int *global_mem, const std::string&);

template<typename T0 = int, typename T1 = int, typename T2 = int, typename T3 = int, typename T4 = int, typename T5 = int>
class IsaExecutor : public RootFunc
{
public:
    T0 sim_;
    T1 cmp_core_;
    T2 arg2_;
    T3 arg3_;
    T4 arg4_;
    T5 arg5_;

    IsaExecutor(T0 arg0 = 0, T1 arg1 = 0, T2 arg2 = 0, T3 arg3 = 0, T4 arg4 = 0, T5 arg5 = 0) :
        sim_(arg0),
        cmp_core_(arg1),
        arg2_(arg2),
        arg3_(arg3),
        arg4_(arg4),
        arg5_(arg5)
    {};

#include "global_memory.h"
#include "executor.cpp"

    static inline void write_register(int *addr, int reg, int value)
    {
        if (reg >= MAX_REG_ID) {
            return;
        }
        addr[reg] = value;
    }
   

    void Run(const std::string& kernel_name)
    {
        int private_mem[MAX_REG_ID];
        write_register(private_mem, GLOBAL_ID, global_flatten_id_);
        write_register(private_mem, GROUP_ID, group_flatten_id_);
        write_register(private_mem, GLOBAL_ID_X, global_id_x_);
        write_register(private_mem, GLOBAL_ID_Y, global_id_y_);
        write_register(private_mem, GLOBAL_ID_Z, global_id_z_);
        write_register(private_mem, TID_X, local_id_x_);
        write_register(private_mem, TID_Y, local_id_y_);
        write_register(private_mem, TID_Z, local_id_z_);
        write_register(private_mem, NTID_X, local_size_x_);
        write_register(private_mem, NTID_Y, local_size_y_);
        write_register(private_mem, NTID_Z, local_size_z_);
        write_register(private_mem, CTAID_X, group_id_x_);
        write_register(private_mem, CTAID_Y, group_id_y_);
        write_register(private_mem, CTAID_Z, group_id_z_);
        write_register(private_mem, NCTAID_X, group_num_x_);
        write_register(private_mem, NCTAID_Y, group_num_y_);
        write_register(private_mem, NCTAID_Z, group_num_z_);
        write_register(private_mem, WARP_SIZE, wrap_size_);
        assert(kernel_name != ""); // it is only valid for llvm-ir IsaExecutor
        KernelRun((uint64 *)kernel_addr_, (uint64 *)kernel_args_, private_mem, kernel_name);
    }
};


extern "C" {

RootFunc* CreateKernel(uint64* kernelCode, uint64* kernelArg)
{
    return  dynamic_cast<RootFunc*>(new IsaExecutor<uint64*, uint64*>(kernelCode, kernelArg));
}

RootFunc* CreateRootFunc(uint64* kernelCode, uint64* kernelArg)
{
    return  CreateKernel(kernelCode, kernelArg);
}

}

