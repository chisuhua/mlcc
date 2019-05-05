#ifndef KERNEL_LOADER_H
#define KERNEL_LOADER_H
#include <iostream>
#include <fstream>
class kernel_loader {
public :
    #define MAX_BUF_SIZE 8 * 1024
    enum load_type_t {
        LOAD_FROM_FILE = 0,
        LOAD_FROM_MEM,
        LOAD_SUPPORT
    };
protected :
    char buf_pool[MAX_BUF_SIZE];
    char *buf_start_addr;
    uint32_t buf_size;
protected :
    virtual uint32_t get_sec_header_size()
    {
        return 0;
    }

    virtual uint32_t load_kernel_from_file(char *bc_file_name)
    {
        uint32_t read_len = 0;
        std::ifstream fin(bc_file_name);
        char *kernel_buf = this->get_kernel_start_addr();

        fin.read(kernel_buf, this->get_max_kernel_buf_size());
        read_len = fin.gcount();
        fin.close();
        std::cout << "read len " << read_len << " \n";
        return read_len;
    }

    virtual uint32_t load_kernel_from_mem(char *buf)
    {
        if (!buf) {
            return 0;
        }
        this->buf_start_addr = buf;
        return 0;
    }

public :
    kernel_loader() {
        this->buf_start_addr = NULL;
        this->buf_size = 0;
    }

    void alloc_buffer()
    {
        this->buf_start_addr = this->buf_pool;
        this->buf_size = MAX_BUF_SIZE;
    }

    virtual int load_kernel(char *data, uint8_t load_type)
    {
        if (load_type == LOAD_FROM_FILE) {
            this->alloc_buffer();
            return this->load_kernel_from_file(data);
        } else  {
            return this->load_kernel_from_mem(data);
        }
    }

    /*
     * kernel buff address, started with Magic number, extar headers:
     *
     * |--------------------------------------| <-  start address
     * |      [ magic number ]                |
     * |--------------------------------------|
     * |      [ extra headers ]               |
     * |--------------------------------------|
     * |                                      |
     * |                                      |
     * |       kernel code                    |
     * |                                      |
     * |--------------------------------------| 
     */
    virtual char* get_kernel_buf()
    {
        return this->get_buf_start_addr();
    }

   
    /*
     * get kernel buf length, including the extra headers.
     * |--------------------------------------| -----
     * |      [ magic number ]                |   ^  
     * |--------------------------------------|   |
     * |      [ extra headers ]               |
     * |--------------------------------------| length
     * |                                      |
     * |                                      |
     * |       kernel code                    |   |
     * |                                      |   v
     * |--------------------------------------| -----
    */
    virtual uint32_t get_kernel_buf_len()
    {
        return this->get_max_buf_size();
    }

    /*
     * get kernel entry start address.
     * |--------------------------------------| 
     * |      [ magic number ]                |
     * |--------------------------------------|
     * |      [ extra headers ]               |
     * |--------------------------------------| <-  start address
     * |                                      |
     * |                                      |
     * |       kernel code                    |
     * |                                      |
     * |--------------------------------------| 
    */
    virtual char* get_kernel_start_addr()
    {
        return this->get_buf_start_addr() + this->get_sec_header_size();
    } 

    virtual char* get_buf_start_addr()
    {
        return this->buf_start_addr;
    }

    virtual uint32_t get_max_buf_size()
    {
        return this->buf_size;
    }

    virtual uint32_t get_max_kernel_buf_size()
    {
        return this->get_max_buf_size() - this->get_sec_header_size();
    }

    /*
     * get kernel length, not include the extra headers
     * |--------------------------------------|
     * |      [ magic number ]                |  
     * |--------------------------------------|
     * |      [ extra headers ]               |
     * |--------------------------------------|-----   
     * |                                      |   |
     * |                                      |  length
     * |       kernel code                    |   
     * |                                      |   |
     * |--------------------------------------| -----
     */
    virtual uint32_t get_kernel_len()
    {
        return this->buf_size;
    }

    virtual void add_hdr_section(uint32_t hdr_type, uint32_t len, char *data)
    {
        return;
    }

    virtual char *get_section_data_pointer(uint32_t hdr_type)
    {
        return NULL;
    }

    virtual void dump_kernel_header()
    {
        std::cout << "Empty header!\n";
    }
};

#endif
