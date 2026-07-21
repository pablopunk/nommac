APP = build/Nommo Night.app
SIGN_IDENTITY = Developer ID Application: Pablo Varela (2TZ4Q825M7)

.PHONY: build test install run clean

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	ditto .build/release/NommoNight "$(APP)/Contents/MacOS/NommoNight"
	ditto Resources/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --deep --options runtime --timestamp=none --sign "$(SIGN_IDENTITY)" "$(APP)"

test:
	swift test

install: build
	mkdir -p "/Users/pablopunk/Applications"
	ditto "$(APP)" "/Users/pablopunk/Applications/Nommo Night.app"

run: install
	open "/Users/pablopunk/Applications/Nommo Night.app"

clean:
	swift package clean
	rm -rf build
