#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ts=4 sw=4 sts=4 expandtab

import sys
import re

in_filename = sys.argv[1]
out_filename = sys.argv[2]

out = open(out_filename, 'w')

start_yaml = False
end_yaml = False
p_start = re.compile(r'^---')
p_end = re.compile(r'^\...$')

with open(in_filename) as inf:
  lines = inf.readlines()
  for line in lines:
      if (start_yaml and p_end.findall(line)):
          end_yaml = True
      if ( not start_yaml and p_start.findall(line)):
          start_yaml = True
          continue
      if (start_yaml and (not end_yaml)):
          out.write(line)

out.close()
