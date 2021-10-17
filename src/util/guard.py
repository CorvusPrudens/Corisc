
from os import path
from os import listdir

def write_guards(*filenames):
  for file in filenames:
    name = path.basename(file).upper()
    name = name[:name.rfind('.')] + '_GUARD'
    original = []
    with open(file, 'r') as f:
      original = [line for line in f]
    
    with open(file, 'w') as f:
      str1 = f"`ifndef {name}\n"
      str2 = f"`define {name}\n"
      f.write(str1)
      f.write(str2)
      for line in original:
        f.write(line)
      str3 = f"`endif // {name}\n"
      f.write(str3)

def write_guards_all(directory):
  files = listdir(directory)
  targets = []
  for file in files:
    if '.v' in file[-2:]:
      targets.append(path.join(directory, file))
  write_guards(*targets)
  num_files = len(targets)
  s = 's' if num_files != 1 else ''
  print(f'Wrote guards for {num_files} file{s}! ^.^')

if __name__ == '__main__':
  from sys import argv
  if path.isdir(argv[1]):
    write_guards_all(argv[1])
  else:
    write_guards(*argv[1:])
    num_files = len(argv) - 1
    s = 's' if num_files != 1 else ''
    print(f'Wrote guards for {num_files} file{s}! ^.^')
        