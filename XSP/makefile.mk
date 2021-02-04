all: XSP2lib.o


XSP2lib.o: XSPsys.s XSPfnc.s XSPmem.s XSPout.s XSPset.s XSP128.s XSP512.s XSP512b.s


XSP2lib.o: XSPsys.s
	HAS -o $@ $^ > log.txt || type log.txt

