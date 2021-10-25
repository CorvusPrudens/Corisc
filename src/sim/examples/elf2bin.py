from functools import reduce
from sys import exit

def little_endian(data, length):
  value = 0
  for i in range(length):
    value |= data[i] << (8 * i)
  return value

def read_uint(data):
  return little_endian(data, len(data))

is_64 = False

def read_elfn(data, offset):
  if is_64:
    return read_uint(data[offset:offset+8])
  else:
    pass

extract = {
  'uint32_t': lambda x, y : read_uint(x),
}

def compare_list(list1, list2):
  comparison = map(lambda x, y : x == y, list1, list2)
  return reduce(lambda x, y : x and y, comparison, True)

def read_elf(filepath):
  data = []
  with open(filepath, 'rb') as file:
    data = list(file.read())

  elf_magic = [127, 69, 76, 70] # 0x7f E L F
  
  if not compare_list(data[:4], elf_magic):
    print("Error: input file is not a valid elf")
    exit(1)
  
  EI_CLASS = ('ELFCLASSNONE', 'ELFCLASS32', 'ELFCLASS64')[data[4]]
  EI_DATA = ('ELFDATANONE', 'ELFDATA2LSB', 'ELFDATA2MSB')[data[5]]

  addr_bytes = {'ELFCLASSNONE': 4, 'ELFCLASS32': 4, 'ELFCLASS64': 8}[EI_CLASS]

  EI_VERSION = ('EV_NONE', 'EV_CURRENT')[data[6]]
  EI_OSABI = (
    'ELFOSABI_NONE',
    'ELFOSABI_SYSV',
    'ELFOSABI_HPUX',
    'ELFOSABI_NETBSD',
    'ELFOSABI_LINUX',
    'ELFOSABI_SOLARIS',
    'ELFOSABI_IRIX',
    'ELFOSABI_FREEBSD',
    'ELFOSABI_TRU64',
    'ELFOSABI_ARM',
    'ELFOSABI_STANDALONE',
  )[data[7]]
  EI_ABIVERSION = data[8]
  EI_PAD = data[9]
  # EI_NIDENT = data[10]
  EI_NIDENT = 16

  print(EI_CLASS, EI_DATA, EI_VERSION, EI_OSABI, addr_bytes)

  e_type = ('ET_NONE', 'ET_REL', 'ET_EXEC', 'ET_DYN', 'ET_CORE')[read_uint(data[EI_NIDENT:EI_NIDENT+2])]
  e_machine = read_uint(data[EI_NIDENT+2:EI_NIDENT+4])
  # e_machine = (
  #   'EM_NONE', 'EM_M32', 'EM_SPARC', 'EM_386', 'EM_68K',
  #   'EM_88K', 'EM_860', 'EM_MIPS', 'EM_PARISC', 'EM_SPARC32PLUS',
  #   'EM_PPC', 'EM_PPC64', 'EM_S390', 'EM_ARM', 'EM_SH', 'EM_SPARCV9',
  #   'EM_IA_64', 'EM_X86_64', 'EM_VAX',
  # )[read_uint(data[EI_NIDENT+2:EI_NIDENT+4])]
  e_version = ('EV_NONE', 'EV_CURRENT')[read_uint(data[EI_NIDENT+4:EI_NIDENT+8])]

  e_entry = read_uint(data[EI_NIDENT+8:EI_NIDENT+8 + addr_bytes])
  e_phoff = read_uint(data[EI_NIDENT+8 + addr_bytes:EI_NIDENT+8 + addr_bytes*2])
  e_shoff = read_uint(data[EI_NIDENT+8 + addr_bytes*2:EI_NIDENT+8 + addr_bytes*3])

  offset = EI_NIDENT+8 + addr_bytes*3

  e_flags = read_uint(data[offset:offset+4])
  e_ehsize = read_uint(data[offset+4:offset+6])
  e_phentsize = read_uint(data[offset+6:offset+8])
  e_phnum = read_uint(data[offset+10:offset+12])
  program_header_table_size = e_phentsize * e_phnum

  e_shentsize = read_uint(data[offset+12:offset+14])
  e_shnum = read_uint(data[offset+14:offset+16])
  section_header_table_size = e_shentsize * e_shnum
  e_shstrndx = read_uint(data[offset+16:offset+18])

  print(e_shstrndx)

if __name__ == '__main__':
  import sys
  read_elf(sys.argv[1])