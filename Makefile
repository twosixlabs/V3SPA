
# OS X 10.8 Sublime Text 2 hack
#PATH := $(PATH):/usr/local/bin

COFFEE = PATH=$(PATH) coffee
LESS = PATH=$(PATH) lessc

VESPA_JS_OUT = static/js/vespa.js
VESPA_JS_SRC = src/vespa.litcoffee  \
               src/models.litcoffee \
               src/router.litcoffee \
               src/editor.litcoffee

VESPA_CSS_OUT = static/css/vespa.css
VESPA_CSS_SRC = src/vespa.less       \
                src/editor.less      \
                src/less/common.less \
                src/less/define.less

TESTDATA_OUT = static/position.js
TESTDATA_SRC = src/position.litcoffee

all: $(VESPA_JS_OUT) $(VESPA_CSS_OUT) $(TESTDATA_OUT)
	@make -C external/avispa
	@cp -f external/avispa/out/avispa.js static/js/
	@cp -f external/avispa/out/avispa.css static/css/

$(VESPA_JS_OUT): $(VESPA_JS_SRC)
	$(COFFEE) -j $(VESPA_JS_OUT) -c $(VESPA_JS_SRC)

$(VESPA_CSS_OUT): $(VESPA_CSS_SRC)
	$(LESS) -x --no-color --include-path=src/less $< $@

$(TESTDATA_OUT): $(TESTDATA_SRC)
	$(COFFEE) -b -j $(TESTDATA_OUT) -c $(TESTDATA_SRC)

clean:
	@find . -type f -name \*.pyc -exec rm -f {} +
	@make -C external/avispa clean

distclean: clean
	@rm -f $(VESPA_JS_OUT) $(VESPA_CSS_OUT)
