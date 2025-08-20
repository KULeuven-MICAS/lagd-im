# Copyright 2025 KU Leuven.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import argparse
import os


class ScriptsParserClass():
    def __init__(self, args=None):
        self.parser = argparse.ArgumentParser(description='Gets options from command line.')
        self.init_parser()
        self.args = self.parser.parse_args(args) if args else self.parser.parse_args()
        self.check_args()
        self.init_attr()
        self.reduce_args()

    def init_parser(self):
        raise NotImplementedError

    def set_defaults(self):
        raise NotImplementedError

    def check_args(self):
        raise NotImplementedError

    def init_attr(self):
        pass

    def reduce_args(self):
        raise NotImplementedError


class ParserClass(ScriptsParserClass):
    def __init__(self):
        super().__init__()

    def init_parser(self):
        self.parser.add_argument('-f', '--file', type=str, help='HDL file path')

    def set_defaults(self):
        pass

    def check_args(self):
        if not os.path.isfile(self.args.file):
            print('File {} not found'.format(self.args.file))
            raise FileNotFoundError

    def reduce_args(self):
        pass
