##-*- Mode: GNUmakefile -*-

PODS = $(sort $(wildcard *.pod))
TARGETS = $(PODS:.pod=.txt) $(PODS:.pod=.html)

DOCURL ?= https://kaskade.dwds.de/dstar/doc
PODPP  ?= perl -pe 's{\$$doc}{$(DOCURL)}g;'

#POSTPP ?= perl -pe 's{\Qhref="$(DOCURL)\E}{href=".}g;'
POSTPP ?= cat

all: $(TARGETS)
readme: $(TARGETS)

txt: $(PODS:.pod=.txt)
%.txt: %.pod
	$(PODPP) $< | pod2text - $@

html: $(PODS:.pod=.html)
%.html: %.pod
	$(PODPP) $< | pod2html --css=perlpod.css | $(POSTPP) > $@
	-rm -f pod2htm*tmp


##-- TODO: publish,sync
#publish:
#	rsync $(TARGETS) kaskade.dwds.de:/home/ddc-dstar/dstar/doc/
#
#sync:
#	svn up $(foreach d,corpus/build corpus/server corpus/web sources deps,../$(d)/README*)
#	ssh kaskade.dwds.de "cd $$PWD && svn up"

clean:
	rm -f $(PODS:.pod=.txt) $(PODS:.pod=.html) pod2htm*
