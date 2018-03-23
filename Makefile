all: release

release:
	swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12" -c release
	mv .build/release/Nightscout-CLI /usr/local/bin/ns

debug:
	swift build -Xswiftc "-target" -Xswiftc "x86_64-apple-macosx10.12" -c debug
	mv .build/debug/Nightscout-CLI /usr/local/bin/ns

xcodeproj: debug
	swift package generate-xcodeproj

test: debug
	ns
