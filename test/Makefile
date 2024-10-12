include ../Makefile.base

TESTFILE ?= TestSimpleUtils.bsv
TOPMODULE ?= mkTestSimpleH2CCore

SIMSCRIPT = $(BUILDDIR)/$(TOPMODULE).sh

compile:
	mkdir -p $(BUILDDIR)
	bsc -elab -sim -verbose $(BLUESIMFLAGS) $(DEBUGFLAGS) $(DIRFLAGS) $(MISCFLAGS) $(RECOMPILEFLAGS) $(RUNTIMEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -g $(TOPMODULE) $(TESTFILE)

link: compile
	bsc -sim $(BLUESIMFLAGS) $(DIRFLAGS) $(RECOMPILEFLAGS) $(SCHEDFLAGS) $(TRANSFLAGS) -e $(TOPMODULE) -o $(SIMSCRIPT)

simulate: link
	$(SIMSCRIPT)

clean:
	rm -rf $(BUILDDIR)

.PHONY: compile link simulate clean
.DEFAULT_GOAL := simulate