
void KernelRun(uint64* program, uint64* argument, int *private_mem, const std::string& kernel_name)
{
    isa_run_kernel(program, argument, private_mem, kernel_name);
}
