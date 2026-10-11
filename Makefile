.PHONY: build test install repair uninstall

build:
	python3 build.py

test:
	python3 test.py

# Finder is relaunched so stale file icons disappear after installation.
install: test build
	python3 install.py --restart-finder

repair: install

uninstall:
	python3 uninstall.py
