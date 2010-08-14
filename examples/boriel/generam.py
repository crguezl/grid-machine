#!/usr/bin/python
# -*- coding: utf-8 -*-

''' genera una matriz de N x N.
Uso: generam.py N
'''

import sys
from random import uniform as rand

INTERVALO = (0, 10)

cols = rows = int(sys.argv[1])

print rows, cols
for x in range(cols):
	for y in range(rows):
		print rand(INTERVALO[0], INTERVALO[1]),

	print

