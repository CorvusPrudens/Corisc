from re import compile
import os

"""
NOTE -- this utility makes a few assumptions
1. The module's name is the same as its file
2. There's only one module per file
3. The indentation is 2 spaces
4. The search space isn't very big (careful with large submodules)
"""

param_regex = compile(r'module +([A-Za-z_][A-Za-z_0-9]*)( |[\r\n\t])*(#\((.|[\r\n\t])+?\))( |[\r\n\t])*(\((.|[\r\n\t])+?\))')
noparam_regex = compile(r'module +([A-Za-z_][A-Za-z_0-9]*)( |[\r\n\t])*(\((.|[\r\n\t])+?\))')
param_item_regex = compile(r'([A-Za-z_][A-Za-z_0-9]*) *(=.*)')
item_regex = compile(r'(input|output|parameter) +(wire|reg)? *(\[.+?\])? *([A-Za-z_][A-Za-z_0-9]*)')
multiline_regex = compile(r'/\*(.|[\n\t\r])*?\*/')
inline_regex = compile(r'//(.|[\r\n\t])*?\n')

def _sar(string: str, regex, replace: str='', group: int=0, ignore_first: bool=False, ignore_last: bool=False) -> str:
    """
    Search and replace using regex. Can optionally keep the first 
    or last character in the match, or only replace a group within a match.
    """
    offset = 1 if ignore_first else 0
    endoff = 1 if ignore_last else 0
    match = regex.search(string)
    while (match is not None):
        string = string[:match.start(group) + offset] + replace + string[match.end(group) - endoff:]
        match = regex.search(string, pos=match.start(group) + offset + len(replace))
    
    return string

# Recursively search for module
def find_mod(mod_name, search_dir):
  target = mod_name if '.v' in mod_name else mod_name + '.v'
  subdirs = False
  for item in os.listdir(search_dir):
    fullpath = os.path.join(search_dir, item)
    if os.path.isdir(fullpath):
      condition, f = find_mod(mod_name, fullpath)
      if condition:
        return True, f
    else:
      if os.path.basename(item) == target:
        return True, fullpath
  return False, ''

def gen_mod(modpath, insertpath, insertline):
  insertline = insertline - 1 if insertline > 0 else insertline

  with open(modpath, 'r') as file:
    moddata = file.read()

  match = param_regex.search(moddata)
  if match is not None:
    params = match.group(3)
    items = match.group(6)
  else:
    match = noparam_regex.search(moddata)
    params = None
    items = match.group(3)
  name = match.group(1)

  if params is not None:
    params = _sar(params, multiline_regex, replace=' ')
    params = _sar(params, inline_regex, replace='\n')
    param_list = [param_item_regex.search(line).group(1) for line in params.split(',')]
  
  items = _sar(items, multiline_regex, replace=' ')
  items = _sar(items, inline_regex, replace='\n')

  item_list = [item_regex.search(line).group(4) for line in items.split(',')]

  if params is not None:
    module = f'  {name} #(\n'
    module += '\n'.join([f'    .{p}(),' for p in param_list])[:-1]
    module += f'\n  ) {name.upper()} (\n'
    module += '\n'.join([f'    .{i}(),' for i in item_list])[:-1]
    module += '\n  );\n'
  else:
    module = f'  {name} {name.upper()} (\n'
    module += '\n'.join([f'    .{i}(),' for i in item_list])[:-1]
    module += '\n  );\n'
  
  with open(insertpath, 'r') as file:
    data = [line for line in file]
  
  if insertline > len(data):
    insertline = len(data) - 1

  data.insert(insertline, module)

  with open(insertpath, 'w') as file:
    file.write(''.join(data))
  
  return name, insertpath, insertline + 1




if __name__ == '__main__':
  import argparse

  parser = argparse.ArgumentParser(description='Insert verilog module boilerplate into any file.')
  parser.add_argument('module', type=str,
                      help='the module to draw from')
  parser.add_argument('target',  type=str,
                      help='the insertion target')
  parser.add_argument('line', type=int,
                       help='the line to insert the module')
  parser.add_argument('-i', type=str, default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "../"),
                      help='the root directory for module searching')

  args = parser.parse_args()
  found, module = find_mod(args.module, args.i)

  if not found:
    print(f'Error: unable to find module "{args.module}"!')
    exit(1)

  name, path, line = gen_mod(module, args.target, args.line)
  print(f'Successfully generated "{name}" module in "{path}" at line {line}!')
