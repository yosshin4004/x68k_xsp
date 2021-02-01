all: PCG90.o

PCG90.o: PCG90.s
	HAS -o $@ $^ > log.txt || type log.txt

