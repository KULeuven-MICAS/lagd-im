# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

from parsers import ParserClass
import os

parser = ParserClass()
file_list = []
vars_dict = {}

def parse_exec_command(line):
    start_idx = line.find('exec')
    end_idx = line.find(']', start_idx)
    exec_cmd = line[start_idx + 5:end_idx].strip()
    exec_output = os.popen(exec_cmd).read().strip()
    return start_idx, end_idx, exec_output

with open(parser.args.file, 'r') as file:
    IN_FILE_LIST = False
    for line in file:
        if line.startswith(f'set {parser.args.target}'):
            IN_FILE_LIST = True
            continue
        elif line.startswith(']'):
            IN_FILE_LIST = False
        elif line.startswith('set') and 'list' not in line:
            if 'exec' in line:
                # Handle exec commands in variable assignments
                start_idx, end_idx, exec_output = parse_exec_command(line)
                var, value = line[:start_idx].split()[1:], exec_output + line[end_idx + 1:].strip()
            else:
                var, value = line.split()[1:]
                vars_dict[var] = value

        if IN_FILE_LIST:
            if 'exec' in line:
                # Handle exec commands
                start_idx, end_idx, exec_output = parse_exec_command(line)
                file_list.append(exec_output+line[end_idx + 1:].split()[0].strip('"'))
            else:
                file_list.append(line.strip().split()[0].strip('"'))

# Substitute variables ${VARS} in file_list with values from vars_dict
exp_file_list = []
for file in file_list:
    for var in vars_dict.keys():
        if '${' + var + '}' in file:
            file = file.replace('${' + var + '}', vars_dict[var])
    if parser.args.target == 'INCLUDE_DIRS':
        # fetch every file in the include directory
        include_dir = file
        if os.path.isdir(include_dir):
            for root, dirs, files in os.walk(include_dir):
                for f in files:
                    if f.endswith('.vh') or f.endswith('.svh'):
                        exp_file_list.append(os.path.join(root, f))
    else:
        exp_file_list.append(file)

file_list_str = ' '.join(exp_file_list)

print(file_list_str)
