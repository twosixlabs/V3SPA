
COFFEE = coffee
LESS = lessc

AVISPA_JS_OUT = out/avispa.js
AVISPA_JS_SRC = src/avispa.litcoffee \
                src/objects/group.litcoffee \
                src/objects/node.litcoffee \
                src/objects/link.litcoffee

AVISPA_CSS_OUT = out/avispa.css
AVISPA_CSS_SRC = src/avispa.less

all: $(AVISPA_JS_OUT) $(AVISPA_CSS_OUT)

$(AVISPA_JS_OUT): $(AVISPA_JS_SRC)
	$(COFFEE) -j $(AVISPA_JS_OUT) -c $(AVISPA_JS_SRC)

$(AVISPA_CSS_OUT): $(AVISPA_CSS_SRC)
	$(LESS) $< $@
