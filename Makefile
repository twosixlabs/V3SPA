
.PHONY: default dist

default:  external/svg-pan-zoom/svg-pan-zoom.js node_modules tmp/bulk
	gulp

external/svg-pan-zoom/svg-pan-zoom.js:
	git submodule update --init

node_modules:
	npm install

tmp/bulk:
	mkdir -p tmp/bulk

dist: static api/bin/lobster-server
	tar cvfz V3SPA.tar.gz api/* etc/* server_templates/* static/* tmp/bulk README.md requirements.txt vespa.py

api/bin/lobster-server: lobster/src/.cabal-sandbox/bin/v3spa-server: 
	cp $< $@

lobster/src/.cabal-sandbox/bin/v3spa-server: 
	$(MAKE) -C lobster/src

