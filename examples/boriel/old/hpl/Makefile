CC=gcc
FLAGS=-Wall

all: matrix

test:
	./matrix p1.dat p2.dat

matrix: matrix.c
	$(CC) $(FLAGS) matrix.c -o $@

