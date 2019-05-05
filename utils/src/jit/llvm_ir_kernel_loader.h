#ifndef LLVM_IR_KERNEL_LOADER_H
#define LLVM_IR_KERNEL_LOADER_H

#include "kernel_loader.h"
class llvm_ir_kernel_loader : public kernel_loader {

public :

    #define LLVM_IR_KERNEL_MAGIC  (('b' << 8) + 'c')
    typedef enum {
        HDR_SEC_KERNEL_CODE = 0,
        HDR_SEC_FILE_NAME,
        HDR_SEC_ENTRY_NAME,
        HDR_SEC_UNKNOWN,
        MAX_HDR_SEC_NUM = HDR_SEC_UNKNOWN
    }hdr_section_type_t;

    typedef struct {
        uint32_t section_type;
        uint32_t offset;
        uint32_t length;
    }hdr_section_t;

    typedef struct {
        uint32_t magic_number;
        hdr_section_t sec[MAX_HDR_SEC_NUM];

    }kernel_code_hdr_t;
private :
    kernel_code_hdr_t *kc_hdr;


private :
    void init_kernel_header()
    {
        this->kc_hdr = (kernel_code_hdr_t *) this->buf_start_addr;
        this->kc_hdr->magic_number = 0;
        for (uint8_t sec_idx = 0; sec_idx < MAX_HDR_SEC_NUM; sec_idx++) {
            this->kc_hdr->sec[sec_idx].section_type = HDR_SEC_UNKNOWN;
            this->kc_hdr->sec[sec_idx].offset = 0;
            this->kc_hdr->sec[sec_idx].length = 0;
        }
    }
protected :
    virtual uint32_t get_sec_header_size() {
        return sizeof(kernel_code_hdr_t);
    }

    bool valid_section(hdr_section_t *sec)
    {
        if (!sec) {
            return false;
        }
        if (sec->section_type == HDR_SEC_UNKNOWN) {
            return false;
        }
        return true;
    }

    char *alloc_section_hdr(uint32_t hdr_type, uint32_t length)
    {
        if (hdr_type >= MAX_HDR_SEC_NUM) {
            return NULL;
        }

        char *buf = this->get_buf_start_addr();
        if (valid_section(&(this->kc_hdr->sec[hdr_type]))) {
            return NULL;
        }
       
        uint32_t free_buf_pos = this->get_sec_header_size();
        uint32_t sec_idx = 0;
        for (sec_idx = 0; sec_idx < MAX_HDR_SEC_NUM; sec_idx++) {
            if(!valid_section(&(this->kc_hdr->sec[sec_idx]))) {
                continue;
            }
            if (free_buf_pos < this->kc_hdr->sec[sec_idx].offset + this->kc_hdr->sec[sec_idx].length) {
                free_buf_pos = this->kc_hdr->sec[sec_idx].offset + this->kc_hdr->sec[sec_idx].length;
            }
        }
        this->kc_hdr->sec[hdr_type].section_type = hdr_type;
        this->kc_hdr->sec[hdr_type].offset = free_buf_pos;
        this->kc_hdr->sec[hdr_type].length = length;

        return (buf + free_buf_pos);
    }

    virtual uint32_t load_kernel_from_file(char *bc_file_name) 
    {
        if (!bc_file_name) {
            return 0;
        }

        this->alloc_buffer();
        this->init_kernel_header();
        this->alloc_section_hdr(HDR_SEC_KERNEL_CODE, 1);
        uint32_t kernel_len = kernel_loader::load_kernel_from_file(bc_file_name);
        this->kc_hdr->sec[HDR_SEC_KERNEL_CODE].length = kernel_len;

        this->alloc_section_hdr(HDR_SEC_FILE_NAME, strlen(bc_file_name) + 1);
        strcpy(this->get_section_data_pointer(HDR_SEC_FILE_NAME), bc_file_name);

        this->kc_hdr->magic_number = LLVM_IR_KERNEL_MAGIC;
        
        return kernel_len;
    }

    virtual uint32_t load_kernel_from_mem(char *buf)
    {
        if (!buf) {
            return 0;
        }
        
        this->buf_start_addr = buf;
        this->buf_size = MAX_BUF_SIZE;

        this->kc_hdr = (kernel_code_hdr_t *) this->buf_start_addr;

        if (this->kc_hdr->magic_number != LLVM_IR_KERNEL_MAGIC) {
            return 0;
        }
        return this->get_kernel_len();
    }

public :
    llvm_ir_kernel_loader() {
//        this->buf_start_addr = this->buf_pool;
//        this->init_kernel_header();
    }

    uint32_t *get_supported_sec_type_lst()
    {
        static uint32_t support_sec_type_lst[] = {
            HDR_SEC_KERNEL_CODE,
            HDR_SEC_FILE_NAME,
            HDR_SEC_ENTRY_NAME,
        };
        return support_sec_type_lst;
    }

    virtual char* get_kernel_start_addr()
    {
        return this->get_section_data_pointer(HDR_SEC_KERNEL_CODE);
    } 

    virtual uint32_t get_kernel_len()
    {
        return this->kc_hdr->sec[HDR_SEC_KERNEL_CODE].length;
    }

    virtual void add_hdr_section(uint32_t hdr_type, uint32_t len, char *data)
    {
        char *buf = alloc_section_hdr(hdr_type, len);
        if (!buf) {
            return;
        }
        memcpy(buf, data, len);
    }

    const char* get_section_name(uint32_t hdr_type)
    {
        if (hdr_type > MAX_HDR_SEC_NUM) {
            return "";
        }
        switch (hdr_type) {
            case HDR_SEC_KERNEL_CODE :
                return "Kernel code";
            case HDR_SEC_FILE_NAME :
                return "File name";
            case HDR_SEC_ENTRY_NAME :
                return "Entry name";
        }
        return "";
    }

    virtual char *get_section_data_pointer(uint32_t hdr_type)
    {
        if (hdr_type >= MAX_HDR_SEC_NUM) {
            return NULL;
        }

        char *buf = this->get_buf_start_addr();
        if (!valid_section(&(this->kc_hdr->sec[hdr_type]))) {
            return NULL;
        }

        return (buf + this->kc_hdr->sec[hdr_type].offset);
    }

    // find out a empty section start point, the buf_len is pointer to 
    virtual uint32_t get_kernel_buf_len()
    {
        uint32_t *all_hdr_type_lst = this->get_supported_sec_type_lst(); 
        uint32_t idx = 0;
        uint32_t buf_len = 0;

        for (idx = 0; idx < MAX_HDR_SEC_NUM; idx++) {
            uint32_t hdr_type = all_hdr_type_lst[idx];
            if (!valid_section(&(this->kc_hdr->sec[hdr_type]))) {
                continue;
            }
            uint32_t cur_sec_end_pos = this->kc_hdr->sec[idx].offset + 
                                       this->kc_hdr->sec[idx].length;
            if (cur_sec_end_pos > buf_len) {
                buf_len = cur_sec_end_pos;
            }
        }
        return buf_len;
    }


    virtual void dump_kernel_header()
    {
        std::cout << "magic number : " << this->kc_hdr->magic_number << "\n";
        for (uint32_t sec_idx = 0; sec_idx < MAX_HDR_SEC_NUM; sec_idx++) {
            if(!valid_section(&(this->kc_hdr->sec[sec_idx]))) {
                continue;
            }
            std::cout << "\nsection name " << this->get_section_name(this->kc_hdr->sec[sec_idx].section_type)
                      << "\noffset "   <<  this->kc_hdr->sec[sec_idx].offset
                      << "\nlength "   << this->kc_hdr->sec[sec_idx].length << "\n";
            if (sec_idx != HDR_SEC_KERNEL_CODE) {
                char *data = this->get_section_data_pointer(sec_idx);
                std::cout << "section data : " << data << "\n";;
            }
        }
    }
};

#endif
