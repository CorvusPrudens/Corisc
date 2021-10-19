import os
import sys
import shutil
import fileinput
import re

def usage():
  print("\nThis script will generate an sby file for a given input");
  print("If no options are given, the program will not generate any output.")
  print("\nUsage: file <option>")
  print("\n\t-h\n\t   print this usage message")
  print("\n\t-d depth\n\t   create sby file with given depth")
  print("\n\t-p\n\t   create sby file with default mode set to prove")
  print()
  exit(0)

def prompt(message):
  valid = False
  attempts = 0
  while not valid:
    response = input('\n' + message + ' [Y/n]\n')
    if response == 'y' or response == '':
      return True
    elif response == 'n':
      return False
    else:
      attempts += 1
      if attempts == 3:
        print('Error, no valid input provided, exiting...')
        exit(5)
      print('Please provide a valid input!')

def isVerilog(filename):
  return '.sv' in filename[-3:] or '.v' in filename[-2:]

def main(argv):

  ##############################################################
  ### I/O
  ##############################################################

  infile = ''
  options_args = {'-d': -1}
  options_noargs = {'-p': False}

  if len(argv) < 2:
    usage()
  for arg in argv:
    if arg == '-h':
      usage()


  directory = argv[1]
  if not os.path.isfile(directory):
    print("Error: unable to find file {}",format(directory), end='\n\n')
    exit(1)


  length = len(argv)
  tempargs = argv
  for i in range(length - 1, -1, -1):
    if tempargs[i] in options_args:
      if i == length - 1 or tempargs[i + 1] in options_args or tempargs[i + 1] in options_noargs:
        print(f"Error: expected argument after option {tempargs[i]}", end='\n\n')
        exit(1)
      options_args[tempargs[i]] = tempargs[i + 1]
      tempargs.pop(i)
      tempargs.pop(i)
    elif tempargs[i] in options_noargs:
      options_noargs[tempargs[i]] = True
      tempargs.pop(i)

  if len(tempargs) > 2:
    print(f'Error: undefined option \"{tempargs[2]}\"\n')
    exit(3)

  if not isVerilog(argv[1]):
    print(f'Error: invalid verilog \"{argv[1]}\"\n')
    exit(69)


  ##############################################################
  ### Main program
  ##############################################################



  slash = directory.rfind('/')
  noslashy = directory if slash == -1 else directory[slash + 1:]

  noext = noslashy[:noslashy.rfind('.')]

  depth = options_args['-d'] if options_args['-d'] != -1 else 10
  isbmc = '# ' if options_noargs['-p'] else ''
  isprove = '# ' if not options_noargs['-p'] else ''
  sbypath = directory[:directory.rfind('.')] + '.sby'

  if os.path.isfile(sbypath):
    if prompt("Do you want to overwrite \"{}\"?".format(sbypath)):
      pass
    else:
      print("Exiting...")
      exit(420)

  with open(sbypath, 'w') as sbyfile:
    sbyfile.write("""
  [options]
  {}mode bmc
  {}depth {}
  {}mode prove

  [engines]
  # smtbmc yices
  # smtbmc boolector
  smtbmc z3

  [script]
  read -formal {}
  prep -top {}
  # opt_merge -share_all

  [files]
  {}
    """.format(isbmc, isbmc, depth, isprove, noslashy, noext, noslashy))

  print("Generated \"{}\"!".format(sbypath))


if __name__ == '__main__':
  main(sys.argv)
