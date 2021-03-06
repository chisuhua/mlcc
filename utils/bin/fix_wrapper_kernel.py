#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ts=4 sw=4 sts=4 expandtab
import sys
import re

in_filename = sys.argv[1]
out_filename = sys.argv[2]


p_func_entry = re.compile(r'^\$.*_kernel')
p_kernel_ctx_arg = re.compile(r'struct.aco_ctx\*\s*undef')

out = open(out_filename, 'w')

with open(in_filename) as inf:
  lines = inf.readlines()
  for line in lines:
      # WE don't need fix, but keep this file for i don't want to change genco.sh
      #if p_func_entry.findall(line):
      #    line = line.replace("_kernel", "")
      if p_kernel_ctx_arg.findall(line):
          line = line.replace("undef", "%co_ctx")
      out.write(line)


out.close()
