#!/usr/bin/env python
# -*- coding: utf-8 -*-
# vim: ts=4 sw=4 sts=4 expandtab
import sys
import re

in_filename = sys.argv[1]
out_filename = sys.argv[2]

kernels = []
for i in sys.argv[3:]:
  kernels.append(i)


p_layout = re.compile(r'^target datalayout')
p_triple = re.compile(r'^target triple')
p_attr_writeonly_ = re.compile(r'^(attributes #.).*writeonly')
p_attr = re.compile(r'^attributes #.')
p_attr_end = re.compile(r'^!llvm.module.flags')

#p_define = re.compile(r'^define')

out = open(out_filename, 'w')

with open(in_filename) as inf:
  lines = inf.readlines()
  for line in lines:
      if p_layout.findall(line):
          out.write('target datalayout = "e-m:e-i64:64-f80:128-n8:16:32:64-S128"\n')
          continue
      if p_triple.findall(line):
          out.write('target triple = "x86_64-unknown-linux-gnu"\n')
          continue
      if p_attr.findall(line):
          continue
      if p_attr_end.findall(line):
          out.write('attributes #0 = { norecurse nounwind uwtable "correctly-rounded-divide-sqrt-fp-math"="false" "denorms-are-zero"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "uniform-work-group-size"="false" "unsafe-fp-math"="false" "use-soft-float"="false" }\n')
          out.write('attributes #1 = { norecurse nounwind uwtable writeonly "correctly-rounded-divide-sqrt-fp-math"="false" "denorms-are-zero"="false" "disable-tail-calls"="false" "less-precise-fpmad"="false" "min-legal-vector-width"="0" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-jump-tables"="false" "no-nans-fp-math"="false" "no-signed-zeros-fp-math"="false" "no-trapping-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+fxsr,+mmx,+sse,+sse2,+x87" "unsafe-fp-math"="false" "use-soft-float"="false" }\n')
      # FIXME 
      line = line.replace('addrspace(3)', 'addrspace(0)')
      line = line.replace('addrspace(4)', 'addrspace(0)')
      line = line.replace('addrspace(5)', 'addrspace(0)')
      line = line.replace('addrspace(1)', 'addrspace(0)')
      #line = line.replace('addrspace(1)', '')
      #line = line.replace('addrspace(3)', '')
      #line = line.replace('addrspace(4)', '')
      #line = line.replace('addrspace(5)', '')
      line = line.replace('addrspacecast', 'bitcast')
      for kernel in kernels:
          line = line.replace(kernel, kernel + "_kernel")
      out.write(line)


out.close()
