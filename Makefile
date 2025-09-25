PPCFLAGS := -FE"obj/" -Fu"TRegExpr/src"

.PHONY: debug
debug:
	@mkdir -p obj
	fpc src/test.pas -dHAVE_DEBUG_LOGS ${PPCFLAGS} -gl
	@mv obj/test .

.PHONY: release
release:
	@mkdir -p obj
	fpc src/test.pas ${PPCFLAGS} -XX -Xs
	@mv obj/test .

.PHONY: clean
clean:
	rm -rf obj
	rm ./test
