SHELL_FILES := bin/ccpr install.sh test/helpers.bash test/stub/claude

.PHONY: check lint test test-bash32 install uninstall

check: lint test

lint:
	shellcheck -x $(SHELL_FILES)

test:
	bats test/

# bash 3.2 and busybox stand in for macOS: old bash, no GNU userland, no flock
test-bash32:
	docker run --rm -v "$(CURDIR)":/src:ro bash:3.2 sh -c \
		'apk add --no-cache git tmux python3 util-linux >/dev/null && \
		 git clone -q --depth 1 https://github.com/bats-core/bats-core.git /bats && \
		 cp -r /src /w && cd /w && /bats/bin/bats test/'

install:
	./install.sh

uninstall:
	./install.sh --uninstall
