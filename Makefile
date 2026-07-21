SIGN_IDENTITY ?= Developer ID Application: Pablo Varela (2TZ4Q825M7)
VERSION ?= $(shell tr -d '[:space:]' < VERSION)

.PHONY: build ci-build test install run release clean

build:
	SIGN_IDENTITY="$(SIGN_IDENTITY)" scripts/build-app.sh

ci-build:
	SIGN_IDENTITY=- scripts/build-app.sh

test:
	swift test

install: build
	mkdir -p "$(HOME)/Applications"
	rm -rf "$(HOME)/Applications/Nommac.app"
	ditto "build/Nommac.app" "$(HOME)/Applications/Nommac.app"

run: install
	open "$(HOME)/Applications/Nommac.app"

release:
	scripts/release.sh "$(VERSION)"

clean:
	swift package clean
	rm -rf build dist
