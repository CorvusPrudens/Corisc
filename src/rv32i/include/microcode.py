
operation_bits = {
  'memory_read': 0,
  'memory_write': 1,
  'mem_addr_pc': 2,
  'mem_addr_load': 3,
  'mem_addr_store': 4,
  'word_size_src': 5,
  'i_immediate': 6,
  'u_immediate': 7,
  'increment_pc': 8,
  'increment_pc2': 9,
  'micro_reset': 10,
  'write_lower_instr': 11,
  'write_upper_instr': 12,
  'register_input_imm': 13,
  'op2_immediate': 14,
  'registers_write': 15,
}

fetch = [
  ['mem_addr_pc', 'increment_pc2'],
  ['mem_addr_pc', 'write_lower_instr', 'increment_pc2'],
  ['write_upper_instr', ]
]

op_fence = [
  ['micro_reset']
]

op_ai = [
  ['op2_immediate', 'registers_write', 'micro_reset']
]

op_a = [
  ['registers_write', 'micro_reset']
]

op_lui = [
  ['register_input_imm', 'register_write', 'micro_reset']
]

# These two are just nops
op_e = [
  ['micro_reset']
]

