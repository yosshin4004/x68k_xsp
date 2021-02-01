all: PCM8Afnc.o

PCM8Afnc.o: PCM8Afnc.s
	HAS -o $@ $^ > log.txt || type log.txt

