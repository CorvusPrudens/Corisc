# TODO -- the ideal, portable setup would be to have loads and
# stores all appear the same to the control unit, not this
# strict 16-bit port size
# mem_addr_store and memory_write can be combined (same for loads!)

from math import ceil, sqrt

operation_bits = {
  'memory_read': 0,
  'memory_write': 1,
  'mem_addr_pc': 2,
  'mem_addr_load': 3,
  'mem_addr_store': 4,
  'word_size_src': 5,
  'pc_save_uepc': 6,
  'pc_restore_uepc': 7,
  'write_pc': 8,
  'mem_addr_vtable': 9,
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
  'load_word': 22,
  'store_byte': 23,
  'store_word': 24,
  'add_mem_addr': 25,
  'build_temp': 26,
  'load_half': 27,
  'cond_write_pc': 28,
  'jal_ras': 29,
  'jalr_ras': 30,
  'clear_interrupt': 31,
}

operations = {
  'fetch': [
    ['mem_addr_pc', 'memory_read', 'write_pc', 'write_lower_instr'],
    ['mem_addr_pc', 'memory_read', 'write_pc', 'write_upper_instr'],
  ],

  # funct3 is in the first half word, so we can load seperate 
  # microcode for lb, lh, and lw
  'op_lb' : [
    ['memory_read', 'mem_addr_load', 'load_byte', 'registers_write', 'micro_reset'],
  ],

  'op_lh' : [
    ['memory_read', 'mem_addr_load', 'load_half', 'registers_write', 'micro_reset'],
  ],

  'op_lw' : [
    ['memory_read', 'mem_addr_load', 'build_temp'],
    ['memory_read', 'mem_addr_load', 'add_mem_addr', 'load_word', 'registers_write', 'micro_reset'],
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
    ['memory_write', 'mem_addr_store', 'micro_reset'],
  ],

  'op_sw' : [
    ['memory_write', 'mem_addr_store'],
    ['memory_write', 'mem_addr_store', 'add_mem_addr', 'store_word', 'micro_reset']
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
    ['register_input_pc', 'registers_write', 'pc_src_jr', 'write_pc', 'jalr_ras', 'micro_reset'],
  ],

  'op_jal' : [
    ['register_input_pc', 'registers_write', 'pc_src_j', 'write_pc', 'jal_ras', 'micro_reset'],
  ],

  # # This is just a nop
  # 'op_e' : [
  #   ['micro_reset'],
  # ],
  'op_mret' : [
    ['write_pc', 'pc_restore_uepc', 'clear_interrupt', 'micro_reset'],
  ],

  'pseudo_op_interrupt' : [
    ['pc_save_uepc', 'write_pc', 'mem_addr_vtable'],
    ['write_pc', 'mem_addr_vtable', 'micro_reset'],
  ],
}

template = """`ifndef RV32I_MICROCODE_GUARD
`define RV32I_MICROCODE_GUARD

module rv32i_microcode
  (
    input wire clk_i,
    input wire [4:0] microcode_addr_i,
    output reg [31:0] microcode_o
  );

  always @(*) begin
    case (microcode_addr_i)
      default: microcode_o = 32'h0;
{}
    endcase
  end

endmodule
`endif // RV32I_MICROCODE_GUARD
"""

def translate_opcode(operation_name, bits, bit_shifts, word_offset):
  lines = [f'      // {operation_name} (offset: {word_offset} words)']
  for step in bits:
    word = 0
    for item in step:
      try:
        word |= 1 << bit_shifts[item]
      except KeyError:
        print(f'oh nu, you tried to add "{item}" in "{operation_name}"! did u really mean that?')
        exit(1)
    lines.append('{:08X}'.format(word))
  if len(lines) == 0:
    lines.append('{:08X}'.format(0))
  return lines

def gen_lut(micro_dict, shifts, outfile):
  total_len = 0 
  for key, item in micro_dict.items():
    for step in item:
      total_len += 1
  
  width = ceil(sqrt(total_len))
  lines = []
  fmt = f'      {{}}\'h{{:0{ceil(width/4)}X}}: microcode_o = 32\'h{{}};'
  with open(outfile, 'w') as file:
    offsets = 0
    index = 0
    for key, item in micro_dict.items():
      steps = translate_opcode(key, item, shifts, offsets)
      lines.append(steps[0])
      for step in steps[1:]:
        lines.append(fmt.format(width, index, step))
        index += 1
      if (key != 'fetch'):
        offsets += len(item)
    file.write(template.format('\n'.join(lines)))


def write_micro(micro_dict, shifts, outfile):

  with open(outfile, 'w') as file:
    offsets = 0
    for key, item in micro_dict.items():
      file.write(' '.join(translate_opcode(key, item, shifts, offsets)[1:]) + '\n')
      if (key != 'fetch'):
        offsets += len(item)

if __name__ == '__main__':
  write_micro(operations, operation_bits, 'microcode.hex')
  gen_lut(operations, operation_bits, '../rv32i_microcode.v')
