#include <elf.h>
#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <vector>
#include <cstring>
#include <fstream>
#include <string>
#include <sstream>

#include "CLI11.hpp"

using std::cout;
using std::vector;
using std::string;

class Elf
{
  public:
    Elf(const char* filename) 
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

    void WriteSectionToBin(const char* section, const char* outfile)
    {
      Elf32_Shdr* output_section = getSectionByName((char*) section);

      FILE* file = fopen(outfile, "wb");
      if (file==NULL) {fputs ("Unable to open output file!",stderr); exit (2);}

      size_t bytes_written = fwrite(bytes_ + output_section->sh_offset, sizeof(uint8_t), output_section->sh_size, file);
      fclose(file);
    }

    void WriteSectionToHex(const char* section, const char* outfile, size_t padding)
    {
      Elf32_Shdr* output_section = getSectionByName((char*) section);

      std::ofstream file(outfile);

      uint8_t* outdata = bytes_ + output_section->sh_offset;
      size_t length = output_section->sh_size;

      if (length > padding)
        throw 1;

      size_t index = 0;
      for (size_t i = 0; i < padding / 8; i++)
      {
        for (size_t j = 0; j < 8; j++)
        {
          if (index < length)
            file << std::setfill ('0') << std::setw(sizeof(uint8_t)*2) << std::hex << (int) outdata[index++] << " ";
          else
            file << std::setfill ('0') << std::setw(sizeof(uint8_t)*2) << std::hex << 0 << " ";
        }
        file << "\n";
      }

      // FILE* file = fopen(outfile, "wb");
      // if (file==NULL) {fputs ("Unable to open output file!",stderr); exit (2);}

      // size_t bytes_written = fwrite(bytes_ + output_section->sh_offset, sizeof(uint8_t), output_section->sh_size, file);
      // fclose(file);
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
      for (size_t i = 0; i < section_headers_.size(); i++)
      {
        char* section_name = getSectionName(i);
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
  CLI::App app{"Utility to extract simple binaries from ELF files"};

  string filename;
  app.add_option("file", filename, "File name")
    ->required()
    ->check(CLI::ExistingFile);
  string outfile;
  app.add_option("-o", outfile, "output file")
    ->default_str("out.bin");

  CLI11_PARSE(app, argc, argv);

  Elf elf(filename.c_str());
  elf.WriteSectionToHex(".text", outfile.c_str(), 1024);
}