
COFFEE = coffee
LESS = lessc

VESPA_JS_OUT = static/js/vespa.js
VESPA_JS_SRC = src/vespa.litcoffee \
               src/models.litcoffee

VESPA_CSS_OUT = static/css/vespa.css
VESPA_CSS_SRC = src/vespa.less \
                src/less/common.less \
                src/less/define.less

all: $(VESPA_JS_OUT) $(VESPA_CSS_OUT)

$(VESPA_JS_OUT): $(VESPA_JS_SRC)
	$(COFFEE) -j $(VESPA_JS_OUT) -c $(VESPA_JS_SRC)

$(VESPA_CSS_OUT): $(VESPA_CSS_SRC)
	$(LESS) -x --no-color --include-path=src/less $< $@
