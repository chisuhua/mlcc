
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <memory>
#include <set>
#include <string>
using namespace std;

#include "jit/llvm_ir_kernel_loader.h"
#include "command_line.h"
// #include "inc/codeobject.h"
// #include "inc/codeobject_writer.h"
// #include "inc/hcs_locks.h"
#include "elfio/elfio.hpp"
#include "yaml-cpp/yaml.h"
#include "msgpack.hpp"


// TODO KernelMeta is also define in codeobject.h, it is better to keep in one place
struct KernelMeta {
   std::string name;
   std::string symbol;
   int max_flat_workgroup_size;
   int kernarg_segment_size;
   int private_segment_fixed_size;
   int wavefront_size;
   std::string language; // OpenCL C
   int kernarg_segment_align;
   int group_segment_fixed_size;
};

using namespace ELFIO;

// NOTE: llvm can write out all hsa codeobject V2/V3 version,
//       but this co_writer only to wrapp llvm-ir in codeobject format
//       it don't use detail codeobject kernel_descript_t struct
//       it is temperately used for cuda-demo
namespace InputFormat {
enum Kind {
    llvmir,
    object,
    invalid
};
};

InputFormat::Kind input_format;
std::string arch;
std::string input; // could be ir or obj
std::string output;
std::string meta;
YAML::Node amd_meta_root_node;
std::vector<std::string> kernel_name_vector;

struct Symbol {
    string name;
    ELFIO::Elf64_Addr value = 0;
    Elf_Xword size = 0;
    Elf_Half sect_idx = 0;
    uint8_t bind = 0;
    uint8_t type = 0;
    uint8_t other = 0;
};

template <typename P>
inline section* find_section_if(elfio& reader, P p)
{
    const auto it = find_if(reader.sections.begin(), reader.sections.end(), move(p));

    return it != reader.sections.end() ? *it : nullptr;
}

inline Symbol read_symbol(const symbol_section_accessor& section, unsigned int idx)
{
    assert(idx < section.get_symbols_num());

    Symbol r;
    section.get_symbol(idx, r.name, r.value, r.size, r.bind, r.type, r.sect_idx, r.other);

    return r;
}

class Program {
public:
    Program() {}
    ~Program() {}

    bool Loadllvmir(const std::string& name)
    {
        kc_loader.load_kernel((char*)(name.c_str()), kernel_loader::LOAD_FROM_FILE);
        // Load the bitcode...
        // kc_buf(kc_loader.get_kernel_buf(), kc_loader.get_kernel_buf_len());
        return true;
    }

    bool LoadElf(const std::string& filename)
    {
        m_elfio.load(filename);
        std::cout << "elf " << filename << " load..." << std::endl;

        auto symtab_section = find_section_if(m_elfio, [](const ELFIO::section* x) {
            return x->get_type() == SHT_SYMTAB;
        });

        if (!symtab_section) return false;

        // const symbol_section_accessor symbols(m_elfio, symtab_section);
        symbols = new symbol_section_accessor(m_elfio, symtab_section);
        for (auto i = 0u; i < symbols->get_symbols_num(); ++i) {
            auto tmp = read_symbol(*symbols, i);
            if (tmp.type == STT_FUNC && tmp.sect_idx != SHN_UNDEF && !tmp.name.empty()) {
                m_symtab.insert(std::make_pair(tmp.name, tmp));
                std::cout << "FUNC symbol found:" << tmp.name << std::endl;
            }
        }
        return true;
    }

    bool AddLlvmIR(std::string& filename)
    {
        Loadllvmir(filename);
        return true;
    }

    bool AddObject(std::string& filename)
    {
        LoadElf(filename);
        return true;
    }


    bool UpdateLlvmIRObject()
    {
        m_elfio.create(ELFCLASS64, ELFDATA2LSB);
        m_elfio.set_os_abi( ELFOSABI_LINUX );  // TODO ELFOSABI_AMDGPU_HSA?
        m_elfio.set_type( ET_REL );
        m_elfio.set_machine( EM_X86_64 );  // TODO schi riscv need change
        section* text_sec = m_elfio.sections.add( ".text" );
        text_sec->set_type      ( SHT_PROGBITS );
        text_sec->set_flags     ( SHF_ALLOC | SHF_EXECINSTR );
        text_sec->set_addr_align( 0x100 );
        text_sec->set_data      ( kc_loader.get_kernel_buf(), kc_loader.get_kernel_buf_len() );

        // Create string table section
        section* str_sec = m_elfio.sections.add( ".strtab" );
        str_sec->set_type      ( SHT_STRTAB );

        // Create string table m_elfio
        string_section_accessor string_accessor( str_sec );

        // Create symbol table section
        section* sym_sec = m_elfio.sections.add( ".symtab" );
        sym_sec->set_type      ( SHT_SYMTAB );
        sym_sec->set_info      ( 2 );
        sym_sec->set_addr_align( 0x4 );
        sym_sec->set_entry_size( m_elfio.get_default_entry_size( SHT_SYMTAB ) );
        sym_sec->set_link      ( str_sec->get_index() );

        // Create symbol table m_elfio
        symbol_section_accessor sym_accessor( m_elfio, sym_sec );

        auto amd_kernel_meta = amd_meta_root_node["amdhsa.kernels"];

        std::map<std::string, KernelMeta> kernel_meta_map;

        // check the meta kernel have corrresponding symbol in symtabl
        for (auto it = amd_kernel_meta.begin(); it != amd_kernel_meta.end(); ++it) {
            // auto kernel_name = (*it)[".name"].as<std::string>();
            auto meta_name = (*it)[".name"].as<std::string>();
            auto meta_symbol = (*it)[".symbol"].as<std::string>();
            std::cout << "name:" << meta_name << std::endl;
            std::cout << "symbol:" << meta_symbol << std::endl;

            KernelMeta meta;
            meta.name = meta_name;
            meta.symbol = meta_symbol;
            kernel_meta_map.insert(std::make_pair(meta_name, meta));

            sym_accessor.add_symbol(string_accessor, meta_name.c_str(), text_sec->get_address(), kc_loader.get_kernel_buf_len(), STB_LOCAL, STT_FUNC, 0, text_sec->get_index());
            sym_accessor.add_symbol(string_accessor, meta_symbol.c_str(), text_sec->get_address(), kc_loader.get_kernel_buf_len(), STB_GLOBAL, STT_LOOS, 1, text_sec->get_index());
        }

        section* note_section = m_elfio.sections.add(".note");
        note_section->set_type(SHT_NOTE);
        note_section_accessor note_accessor(m_elfio, note_section);

        std::stringstream ss;
        using map_type = std::unordered_map<std::string, std::string> ;
        using vec_type = std::vector<map_type>;
        using root_type = std::unordered_map<std::string, vec_type>;

        vec_type kernel_vector;
        for (auto& m: kernel_meta_map) {
            std::string kname = m.first;
            KernelMeta kmeta = m.second;
            map_type name { {".name", kmeta.name}, {".symbol", kmeta.symbol} };
            kernel_vector.push_back(name);
        }

        root_type root;
        root.insert(std::make_pair("PPU.Kernels", kernel_vector));

        msgpack::pack(ss, root);
        note_accessor.add_note(0x20, "PPU.Kernels", ss.str().data(), ss.str().size());

        return true;
    }

    bool UpdateElfObject()
    {
        auto note_section = find_section_if(m_elfio, [](const ELFIO::section* x) {
            return x->get_type() == SHT_NOTE;
        });

        if (!note_section) {
            note_section = m_elfio.sections.add(".note");
            note_section->set_type(SHT_NOTE);
        }
        note_section_accessor note_accessor(m_elfio, note_section);


        auto string_section = find_section_if(m_elfio, [](const ELFIO::section* x) {
            return x->get_type() == SHT_STRTAB;
        });

        if (!string_section) {
            string_section = m_elfio.sections.add(".strtab");
            string_section->set_type(SHT_STRTAB);
        }
        string_section_accessor string_accessor( string_section );

        auto amd_kernel_meta = amd_meta_root_node["amdhsa.kernels"];

        std::map<std::string, KernelMeta> kernel_meta_map;

        // check the meta kernel have corrresponding symbol in symtabl
        for (auto it = amd_kernel_meta.begin(); it != amd_kernel_meta.end(); ++it) {
            // auto kernel_name = (*it)[".name"].as<std::string>();
            auto meta_name = (*it)[".name"].as<std::string>();
            auto meta_symbol = (*it)[".symbol"].as<std::string>();
            std::cout << "name:" << meta_name << std::endl;
            std::cout << "symbol:" << meta_symbol << std::endl;
            if (m_symtab.find(meta_name) == m_symtab.end()) {
                std::cout << "Meta Kernel name " << meta_name << " is not found in elf input" << std::endl;
                return false;
            }

            KernelMeta meta;
            meta.name = meta_name;
            meta.symbol = meta_symbol;
            kernel_meta_map.insert(std::make_pair(meta_name, meta));
        }

        // update the symbol table for kernels
        // for (auto& m: kernel_meta_map) {
        for (auto it=kernel_meta_map.cbegin(); it != kernel_meta_map.cend(); it++) {
            std::string name = it->first;
            KernelMeta meta = it->second;

            auto kernel_address = m_symtab[name].value;
            auto kernel_sect_idx = m_symtab[name].sect_idx;

            (*symbols).add_symbol(string_accessor, meta.symbol.c_str(), kernel_address, 0, STB_GLOBAL, STT_LOOS, 0, kernel_sect_idx);

        }

        // update the note section

        std::stringstream ss;

        using map_type = std::unordered_map<std::string, std::string> ;
        using vec_type = std::vector<map_type>;
        using root_type = std::unordered_map<std::string, vec_type>;

        vec_type kernel_vector;
        for (auto& m: kernel_meta_map) {
            std::string kname = m.first;
            KernelMeta kmeta = m.second;

            map_type name { {".name", kmeta.name}, {".symbol", kmeta.symbol} };
            kernel_vector.push_back(name);
        }

        root_type root;
        root.insert(std::make_pair("PPU.Kernels", kernel_vector));

        msgpack::pack(ss, root);
        // auto oh = msgpack::unpack(ss.str().data(), ss.str().size());
        // msgpack::object obj = oh.get();
        /*
        kmeta_array.push_back(obj);

        std::stringstream root_ss;
        msgpack::pack(root_ss, kmeta_array);
        auto oh = msgpack::unpack(root_ss.str().data(), root_ss.str().size());
        msgpack::object root_obj = oh.get();
        */
        //MapType root_map;
        // root_map.insert(std::make_pair("PPU.Kernels", root_obj));
        //root_map.insert(std::make_pair("PPU.Kernels", obj));

        // std::stringstream root_notes;
        // msgpack::pack(root_notes, root_map);

        // note_accessor.add_note(0x20, "PPU.Kernels", root_notes.str().data(), root_notes.str().size());
        note_accessor.add_note(0x20, "PPU.Kernels", ss.str().data(), ss.str().size());
        /*
        for (auto& kernel_name : kernel_name_vector) {
            printf("co_writer: add symbole for kernel_name %s\n", kernel_name.c_str());
            KernelSymbol* sym = (KernelSymbol*)(code.AddExecutableSymbol(kernel_name, STT_AMDGPU_HSA_KERNEL, STB_GLOBAL, 1));
            code.AddKernelCode(sym, kc_loader.get_kernel_buf(), kc_loader.get_kernel_buf_len());
        }
*/
        return true;
    }

    bool WriteObject(const std::string& output)
    {
        m_elfio.save(output);
        return true;
    }

    llvm_ir_kernel_loader kc_loader;
    elfio m_elfio;
    std::map<std::string, Symbol> m_symtab;
    symbol_section_accessor* symbols;

    /*
  std::vector<ELFIO::segment*> m_segments;
  std::vector<ELFIO::section*> m_sections;
  std::vector<ELFIO::section*> relocationSectionsV3;
*/

private:
    Program(const Program& p);
    Program& operator=(const Program& p);
};

class CodeWriter {

    Program* program;

    // StringRef kc_buf;
    // std::string output_;

public:
    CodeWriter()
        : program(nullptr)
    //        , output_(output)
    {
        // code.handle = 0;
    }

    ~CodeWriter()
    {
        // void *cord = reinterpret_cast<void*>(code.handle);
        // if (cord) { hsa_program_context.CodeObjectFree(cord); }
    }

    bool CreateProgram(const std::string& name)
    {
        program = new Program(); // , brig_major, brig_minor);
        return true;
    }

    bool LoadModule(std::string& name)
    {
        std::cout << "input file is " << name << endl;
        if (input_format == InputFormat::llvmir) {
            std::cout << "input format llvmir " << endl;
            return program->AddLlvmIR(name);
        }
        if (input_format == InputFormat::object) {
            std::cout << "input format object " << endl;
            return program->AddObject(name);
        }
        return false;
    }

    bool WriteCO(const std::string& output)
    {
        if (input_format == InputFormat::llvmir) {
            if (!program->UpdateLlvmIRObject()) {
                std::cout << "Update LLVMIR Object failed " << endl;
                return false;
            }
        }

        if (input_format == InputFormat::object) {
            if (!program->UpdateElfObject()) {
                std::cout << "Update ELF Object failed " << endl;
                return false;
            }
        }

        if (!program->WriteObject(output)) {
            std::cout << "Save Object failed " << endl;
            return false;
        }
        /*
        hsa_status_t hsa_status = HSA_STATUS_SUCCESS;
        hsa_ext_control_directives_t hsa_directives;
        memset(&hsa_directives, 0x0, sizeof(hsa_directives));

        memset(&code, 0x0, sizeof(hsa_code_object_t));

        std::string target("bi-ix");

        hsa_status = program->WriteCO(target.c_str(), 0, "",
            hsa_directives, HSA_CODE_OBJECT_TYPE_PROGRAM, &code);
        if (HSA_STATUS_SUCCESS != hsa_status) {
            cerr << "error: failed to finalize ";
            return false;
        }

        void* cord = reinterpret_cast<void*>(code.handle);
        assert(cord);

        uint64_t cosz = hcs::elf::ElfSize(cord);
        assert(cosz);

        FILE* cof = fopen(output_.c_str(), "wb");
        if (!cof) {
            cerr << "error: failed to open <" << output_ << ">" << endl;
            return false;
        }

        fwrite(cord, cosz, 1, cof);
        fclose(cof);
        */
        return true;
    }
};

void usage()
{
    printf("Usage: co_writer -arch=[llvmir|x86-64] -input=[bc_file|obj] -output=output -meta=meta_file [kernel_name ...]\n");
}

int main(int argc, const char** argv)
{

    CommandLine args(argc, argv);

    if (args.check_cmd_line_flag("help")) {
        std::cout << "-help" << std::endl;
        usage();
        return 0;
    }

    if (args.check_cmd_line_flag("arch")) {
        args.get_cmd_line_argument("arch", arch);
        if (arch.rfind("x86") != std::string::npos) {
            input_format = InputFormat::object;
        } else if (arch.rfind("llvmir") != std::string::npos) {
            input_format = InputFormat::llvmir;
        }
    } else {
        std::cout << "-arch is expected " << std::endl;
        usage();
        return 0;
    }

    if (args.check_cmd_line_flag("input")) {
        args.get_cmd_line_argument("input", input);
    } else {
        std::cout << "-input is expected " << std::endl;
        usage();
        return 0;
    }

    if (args.check_cmd_line_flag("output")) {
        args.get_cmd_line_argument("output", output);
    } else {
        std::cout << "-output is expected " << std::endl;
        usage();
        return 0;
    }

    if (args.check_cmd_line_flag("meta")) {
        args.get_cmd_line_argument("meta", meta);
        std::ifstream file(meta, std::ios::in | std::ios::binary);
        assert(file.is_open() && file.good());

        // Find out file size.
        file.seekg(0, file.end);
        size_t size = file.tellg();
        file.seekg(0, file.beg);

        // Allocate memory for raw code object.
        void* buffer = malloc(size);
        assert(buffer);

        // Read file contents.
        file.read((char*)buffer, size);
        // Close file.
        file.close();

        amd_meta_root_node = YAML::Load((const char*)buffer);
        if (!amd_meta_root_node["amdhsa.kernels"]) {
            std::cout << "meta file is not valid" << std::endl;
            return 0;
        }
        // enable for debug std::cout << meta_root_node << std::endl;
    } else {
        std::cout << "-output is expected " << std::endl;
        usage();
        return 0;
    }

    // args.get_cmd_line_arguments(kernel_name_vector);

    for (auto i = 0u; i < args.args.size(); i++) {
        std::cout << "co_writer: kernel_name " << args.args[i] << std::endl;
        // kernel_name_vector.push_back(argv[i]);
    }

    CodeWriter cw;
    cw.CreateProgram(output); // TODO use better program name
    if (!cw.LoadModule(input)) {
        std::cout << "Fail to load input file " << std::endl;
        return 0;
    }
    if (!cw.WriteCO(output)) {
        std::cout << "Fail to write output file " << std::endl;
        return 0;
    }
}

