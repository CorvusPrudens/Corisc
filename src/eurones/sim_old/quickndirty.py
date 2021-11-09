
import re

opreg = re.compile(r'[0-9abcdef]+:\W*([0-9abcdef]+)\W+(.+?)\n')

with open('build/eurones.txt', 'r') as file:
  instructions = []
  illust = []
  for line in file:
    match = opreg.search(line)
    if match is not None:
      instructions.append(match.group(1))
      illust.append(match.group(2))

while len(instructions) < 32:
  instructions.append('00000000')
  illust.append('^.^')

with open('build/eurones.hex', 'w') as file:
  for inst, ill in zip(instructions, illust):
    file.write(f'{inst} // {ill}\n')
