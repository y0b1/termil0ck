.PHONY: build test bundle dmg run clean

build:
	swift build

test:
	swift test

bundle: build
	./scripts/bundle.sh

dmg:
	swift build -c release
	TERMILOCK_BUILD_CONFIGURATION=release ./scripts/bundle.sh
	./scripts/dmg.sh

run: bundle
	open ./Termilock.app

clean:
	swift package clean
	rm -rf ./Termilock.app
