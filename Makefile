SHELL := /bin/bash

SHELL_SCRIPTS := deploy.sh orb_profile $(wildcard shell_config/*.sh) \
                 $(wildcard tests/*.sh) $(wildcard .githooks/*)

.PHONY: help test lint install hooks

help:
	@echo "userconf targets:"
	@echo "  make test     run the test suite (tests/run_tests.sh)"
	@echo "  make lint     bash -n on every script; shellcheck too if installed"
	@echo "  make install  deploy this config into \$$HOME (./deploy.sh -i)"
	@echo "  make hooks    point git at the version-controlled .githooks/"

test:
	@./tests/run_tests.sh

lint:
	@for f in $(SHELL_SCRIPTS); do bash -n "$$f" || exit 1; done
	@echo "bash -n: clean"
	@if command -v shellcheck >/dev/null; then \
	    shellcheck -S warning $(SHELL_SCRIPTS); \
	else \
	    echo "shellcheck not installed - skipping (optional dependency)"; \
	fi

install:
	@./deploy.sh -i

# Absolute, and anchored to the main checkout rather than $(CURDIR): a relative
# hooksPath is resolved against the cwd, so it silently misses when a ref is
# moved by plumbing from outside any checkout - which is exactly the auto-push
# case. Run from a linked worktree, --git-common-dir still names the main repo.
hooks:
	@root=$$(cd "$$(git rev-parse --git-common-dir)/.." && pwd); \
	 git config core.hooksPath "$$root/.githooks"; \
	 echo "core.hooksPath = $$root/.githooks"
