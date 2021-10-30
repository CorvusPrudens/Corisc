import os


template = "  wire [{size}:0] {vector};"

bit_template = "  assign {vector}[{index}] = {src}[{index}] & ~({sources_less});"

def genpriority(vector, size, src, target, line):
  out =[template.format_map({'vector': vector, 'size': size-1})]
  out.append(f'  assign {vector}[0] = {src}[0];')
  for i in range(1, size):
    sources_less = ' | '.join([f'{src}[{j}]' for j in range(i - 1, -1, -1)])
    out.append(bit_template.format_map({'vector': vector, 'index': i, 'src': src, 'sources_less': sources_less}))
  
  with open(target, 'r') as file:
    data = [line for line in file]
  
  line -= 1

  if len(data) < line:
    line = len(data - 1)
  
  data.insert(line, '\n'.join(out))

  with open(target, 'w') as file:
    file.write(''.join(data))

  

if __name__ == '__main__':
  import argparse

  parser = argparse.ArgumentParser(description='Insert a vector that indicates the lowest active bit in another vector.')
  parser.add_argument('vector', type=str,
                      help='the name of the generated vector')
  parser.add_argument('size', type=int,
                      help='the size of the generated/src vector')
  parser.add_argument('src', type=str,
                      help='the name of the source vector')
  parser.add_argument('target',  type=str,
                      help='the insertion target file')
  parser.add_argument('line', type=int,
                       help='the line to insert the module')

  args = parser.parse_args()

  genpriority(args.vector, args.size, args.src, args.target, args.line)

  print(f'Successfully generated "{args.vector}" vector in "{args.target}" at line {args.line}!')