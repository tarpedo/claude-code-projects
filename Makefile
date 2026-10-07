SHELL_FILES := bin/ccpr install.sh test/helpers.bash test/stub/claude

.PHONY: check lint test install uninstall

check: lint test

lint:
	shellcheck -x $(SHELL_FILES)

test:
	bats test/

install:
	./install.sh

uninstall:
	./install.sh --uninstall
