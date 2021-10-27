# TODO -- the ideal, portable setup would be to have loads and
# stores all appear the same to the control unit, not this
# strict 16-bit port size
# mem_addr_store and memory_write can be combined (same for loads!)

operation_bits = {
  'memory_read': 0,
  'memory_write': 1,
  'mem_addr_pc': 2,
  'mem_addr_load': 3,
  'mem_addr_store': 4,
  'word_size_src': 5,
  'i_immediate': 6,
  'u_immediate': 7,
  'write_pc': 8,
  # 'increment_pc': 9,
  'micro_reset': 10,
  'write_lower_instr': 11,
  'write_upper_instr': 12,
  'register_input_imm': 13,
  'op2_immediate': 14,
  'registers_write': 15,
  'add_pc_upper': 16,
  'pc_src_j': 17,
  'pc_src_jr': 18,
  'pc_src_b': 19,
  'register_input_pc': 20,
  'load_byte': 21,
  'load_half': 22,
  'store_byte': 23,
  'store_half': 24,
  'add_mem_addr': 25,
  'build_temp': 26,
  'register_input_temp': 27,
  'cond_write_pc': 28,
  'mem_word_offset': 29,
}

operations = {
  'fetch': [
    ['mem_addr_pc', 'memory_read', 'write_pc'],
    ['mem_addr_pc', 'memory_read', 'write_lower_instr', 'write_pc'],
    ['write_upper_instr'],
  ],

  # funct3 is in the first half word, so we can load seperate 
  # microcode for lb, lh, and lw
  # loading the address first like this is necessary for reading
  # from bram :c
  'op_lb' : [
    ['memory_read', 'mem_addr_load'],
    ['load_byte', 'registers_write', 'micro_reset'],
  ],

  'op_lh' : [
    ['memory_read', 'mem_addr_load'],
    ['load_half', 'registers_write', 'micro_reset'],
  ],

  'op_lw' : [
    ['memory_read', 'mem_addr_load'],
    ['memory_read', 'mem_addr_load', 'mem_word_offset', 'load_half', 'build_temp'],
    ['load_half', 'register_input_temp', 'registers_write', 'micro_reset'],
  ],

  'op_fence' : [
    ['micro_reset'],
  ],

  'op_ai' : [
    ['op2_immediate', 'registers_write', 'micro_reset'],
  ],

  'op_auipc' : [
    ['register_input_imm', 'add_pc_upper', 'registers_write', 'micro_reset'],
  ],

  # remember to preserve other byte when doing byte-writes
  'op_sb' : [
    ['memory_write', 'mem_addr_store', 'store_byte', 'micro_reset'],
  ],

  'op_sh' : [
    ['memory_write', 'mem_addr_store', 'store_half', 'micro_reset'],
  ],

  'op_sw' : [

  ],

  'op_a' : [
    ['registers_write', 'micro_reset'],
  ],

  'op_lui' : [
    ['register_input_imm', 'registers_write', 'micro_reset'],
  ],

  'op_b' : [
    ['pc_src_b', 'cond_write_pc', 'micro_reset'],
  ],

  'op_jalr' : [
    ['register_input_pc', 'registers_write', 'pc_src_jr', 'write_pc', 'micro_reset'],
  ],

  'op_jal' : [
    ['register_input_pc', 'registers_write', 'pc_src_j', 'write_pc', 'micro_reset'],
  ],

  # These two are just nops
  'op_e' : [
    ['micro_reset'],
  ],
}

def translate_opcode(operation_name, bits, bit_shifts):
  lines = [f'// {operation_name}\n']
  for step in bits:
    word = 0
    for item in step:
      try:
        word |= 1 << bit_shifts[item]
      except KeyError:
        print(f'oh nu, you tried to add "{item}" in "{operation_name}"! did u really mean that?')
        exit(1)
    lines.append('{:08X}'.format(word)[2:])
  if len(lines) == 0:
    lines.append('{:08X}'.format(0)[2:])
  return ' '.join(lines)


def write_micro(micro_dict, shifts, outfile):

  with open(outfile, 'w') as file:
    [file.write(translate_opcode(key, item, shifts) + '\n') for key, item in micro_dict.items()]

if __name__ == '__main__':
  write_micro(operations, operation_bits, 'microcode.hex')
