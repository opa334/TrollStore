pwnify:
	@clang main.m -fobjc-arc -fmodules -mmacosx-version-min=11.0 -o pwnify

install: pwnify
	-@sudo rm /usr/local/bin/pwnify 2>/dev/null || true
	@sudo cp ./pwnify /usr/local/bin/pwnify

clean:
	@rm ./pwnify 2>/dev/null || true