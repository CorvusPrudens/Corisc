import os
from math import log2, ceil

template = """  reg [{logsize}:0] {vector};
  always @(*) begin
    case ({src})
{statements}
    endcase
  end
"""

statement = "      {size}'h{hex}: {vector} = {logsize}'h{value};"

def gendecoder(vector, size, src, target, line):
  logsize = ceil(log2(size))
  lhs_temp = f'{{:0{ceil(size/4)}X}}'
  rhs_temp = f'{{:0{ceil(logsize/4)}X}}'
  print(lhs_temp, rhs_temp)
  stats = '\n'.join([
    statement.format_map
    (
      {
        'size': size, 
        'hex': lhs_temp.format(1 << i), 
        'value': rhs_temp.format(i), 
        'vector': vector,
        'logsize': logsize
      }
    ) 
    for i in range(size)
  ])
  stats += (f'\n      default: {vector} = 0;')

  output = template.format_map({'logsize': logsize-1, 'vector': vector, 'src': src, 'statements': stats})
  
  with open(target, 'r') as file:
    data = [line for line in file]
  
  line -= 1

  if len(data) < line:
    line = len(data - 1)
  
  data.insert(line, output)

  with open(target, 'w') as file:
    file.write(''.join(data))
  

if __name__ == '__main__':
  import argparse

  parser = argparse.ArgumentParser(description='Generate a one-hot to binary decoder')
  parser.add_argument('vector', type=str,
                      help='the name of the generated vector')
  parser.add_argument('src', type=str,
                      help='the name of the source vector')
  parser.add_argument('size', type=int,
                      help='the size of the input vector')
  parser.add_argument('target',  type=str,
                      help='the insertion target file')
  parser.add_argument('line', type=int,
                       help='the line to insert the module')

  args = parser.parse_args()

  gendecoder(args.vector, args.size, args.src, args.target, args.line)

  print(f'Successfully generated "{args.vector}" vector in "{args.target}" at line {args.line}!')