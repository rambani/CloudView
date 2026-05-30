.PHONY: generate open clean test

generate:
	@which xcodegen > /dev/null 2>&1 || (echo "Installing xcodegen..." && brew install xcodegen)
	xcodegen generate

open: generate
	open Cloudoodle.xcodeproj

clean:
	rm -rf Cloudoodle.xcodeproj
	rm -rf .build

test: generate
	xcodebuild test \
		-project Cloudoodle.xcodeproj \
		-scheme Cloudoodle \
		-destination 'platform=iOS Simulator,name=iPhone 15 Pro'

lint:
	@which swiftlint > /dev/null 2>&1 || (echo "Installing swiftlint..." && brew install swiftlint)
	swiftlint lint --strict

format:
	@which swiftformat > /dev/null 2>&1 || (echo "Installing swiftformat..." && brew install swiftformat)
	swiftformat .

.DEFAULT_GOAL := open
