PPCFLAGS := -FE"obj/" -Fu"inc/" -l-

PROGRAMS := src/test.pas \
			src/sadv.pas

debug: PPCFLAGS := $(PPCFLAGS) -gl
.PHONY: debug
debug: $(PROGRAMS)

.PHONY: release
release: PPCFLAGS := $(PPCFLAGS) -XX -Xs
release: $(PROGRAMS)

src/%.pas:
	@mkdir -p obj
	fpc $@ ${PPCFLAGS}

.PHONY: clean
clean:
	rm -rf obj
