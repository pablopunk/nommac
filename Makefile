APP = build/Nommo Night.app

.PHONY: build test install run clean

build:
	swift build -c release
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS"
	ditto .build/release/NommoNight "$(APP)/Contents/MacOS/NommoNight"
	ditto Resources/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP)"

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

