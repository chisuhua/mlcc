#ifndef ISA_EXECUTOR_H
#define ISA_EXECUTOR_H

typedef struct kernel_code_ {
    char *start_addr;
    int  len;
    const char *entry_name;
}kernel_code_t;

typedef struct kernel_arg_ {
    int *in;
    int *out;
}kernel_arg_t;

#endif
