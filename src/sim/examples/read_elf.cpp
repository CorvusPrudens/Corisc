#include <elf.h>
#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <vector>
#include <cstring>

using std::cout;
using std::vector;

class Elf
{
  public:
    Elf(char* filename) 
    {
      FILE* file = fopen(filename, "rb");
      if (file==NULL) {fputs ("Unable to open file!",stderr); exit (1);}

      fseek (file , 0 , SEEK_END);
      elf_size_ = ftell(file);
      rewind (file);

      bytes_ = (uint8_t*) malloc(elf_size_ * sizeof(uint8_t));
      size_t bytes_read = fread(bytes_, sizeof(uint8_t), elf_size_, file);
      fclose(file);

      elf_header_ = (Elf32_Ehdr*) bytes_;

      if (elf_header_->e_ident[EI_CLASS] != ELFCLASS32)
      {
        throw "Error: input file must be 32 bit!";
      }

      for (size_t i = 0; i < elf_header_->e_phnum; i++)
      {
        Elf32_Phdr* ptr = (Elf32_Phdr*)(bytes_ + elf_header_->e_phoff + elf_header_->e_phentsize * i);
        program_headers_.push_back(ptr);
      }

      for (size_t i = 0; i < elf_header_->e_shnum; i++)
      {
        Elf32_Shdr* ptr = (Elf32_Shdr*) (bytes_ + elf_header_->e_shoff + elf_header_->e_shentsize * i);
        section_headers_.push_back(ptr);
      }

      string_table_ = (char*) (bytes_ + section_headers_[elf_header_->e_shstrndx]->sh_offset);
    }
    ~Elf() { free(bytes_); }

    void WriteSectionToFile(const char* section, const char* outfile)
    {
      Elf32_Shdr* output_section = getSectionByName((char*) section);

      FILE* file = fopen(outfile, "wb");
      if (file==NULL) {fputs ("Unable to open output file!",stderr); exit (2);}

      size_t bytes_written = fwrite(bytes_ + output_section->sh_offset, sizeof(uint8_t), output_section->sh_size, file);
      fclose(file);
    }

  private:

    char* getSectionName(size_t section_index)
    {
      size_t index = section_headers_[section_index]->sh_name;
      index = index == 0 ? 1 : index;
      return string_table_ + index;
    }

    Elf32_Shdr* getSectionByName(char* name)
    {
      cout << name << "\n";
      for (size_t i = 0; i < section_headers_.size(); i++)
      {
        char* section_name = getSectionName(i);
        cout << section_name << "\n";
        if (strcmp(section_name, name) == 0)
          return section_headers_[i];
      }
      throw 1;
    }

    uint8_t* bytes_;
    size_t elf_size_;
     Elf32_Ehdr *elf_header_;
    vector<Elf32_Phdr*> program_headers_;
    vector<Elf32_Shdr*> section_headers_;
    char* string_table_;
};

int main(int argc, char** argv)
{

  Elf elf(argv[1]);

  elf.WriteSectionToFile(".text", "exec.bin");

}