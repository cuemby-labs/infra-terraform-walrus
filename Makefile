SHELL := /bin/bash

# Borrowed from https://stackoverflow.com/questions/18136918/how-to-get-current-relative-directory-of-your-makefile
curr_dir := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Borrowed from https://stackoverflow.com/questions/2214575/passing-arguments-to-make-run
rest_args := $(wordlist 2, $(words $(MAKECMDGOALS)), $(MAKECMDGOALS))
$(eval $(rest_args):;@:)

examples := $(shell ls $(curr_dir)/examples | xargs -I{} echo -n "examples/{}")
modules := $(shell ls $(curr_dir)/modules | xargs -I{} echo -n "modules/{}")
targets := $(shell ls $(curr_dir)/hack | grep '.sh' | sed 's/\.sh//g')
$(targets):
	@$(curr_dir)/hack/$@.sh $(rest_args)

help:
	#
	# Usage:
	#
	#   * [dev] `make generate`, generate README file.
	#           - `make generate examples/hello-world` only generate docs and schema under examples/hello-world directory.
	#           - `make generate docs examples/hello-world` only generate README file under examples/hello-world directory.
	#           - `make generate schema examples/hello-world` only generate schema.yaml under examples/hello-world directory.
	#
	#   * [dev] `make lint`, check style and security.
	#           - `LINT_DIRTY=true make lint` verify whether the code tree is dirty.
	#           - `make lint examples/hello-world` only verify the code under examples/hello-world directory.
	#
	#   * [dev] `make test`, execute unit testing.
	#           - `make test examples/hello-world` only test the code under examples/hello-world directory.
	#
	#   * [ci]  `make ci`, execute `make generate`, `make lint` and `make test`.
	#
	@echo


.DEFAULT_GOAL := ci
.PHONY: $(targets) examples $(examples) modules $(modules) tests docs schema

TENV_AUTO_INSTALL:=true
TERRAFORM_ENGINE:=opentofu
ifeq ($(TERRAFORM_ENGINE), terraform)
	TERRAFORM_BINARY:=terraform
else ifeq ($(TERRAFORM_ENGINE), opentofu)
	TERRAFORM_BINARY:=tofu
endif

GO_TEST_OPTS:=
TERRATEST_FILES:=$(wildcard tests/*_test.go)
terratest/go.mod:
	cd tests && \
	rm -rf go.mod && \
	go mod init "terratest"
terratest/go.sum: terratest/go.mod $(TERRATEST_FILES)
	cd tests && \
	rm -rf go.sum && \
	go mod tidy
.PHONY: terratest
terratest: terratest/go.sum
	cd tests && \
	TERRAFORM_BINARY=$(TERRAFORM_BINARY) go test -v -timeout 60m $(GO_TEST_OPTS)

CHECKOV_OPTS:=
security/checkov:
	checkov --directory . $(CHECKOV_OPTS)
security/trivy:
	trivy config .
.PHONY: security
security: security/checkov security/trivy

tflint/fix:
	tflint --init
	tflint --fix
tflint/lint:
	tflint --init
	tflint
.PHONY: tflint
tflint: tflint/lint tflint/fix

.PHONY:
validate:
	$(TERRAFORM_BINARY) init -backend=false
	$(TERRAFORM_BINARY) validate

.PHONY: clean
clean:
	@echo "Removing files and directories listed in .gitignore recursively..."
	@grep -v '^#' .gitignore | grep -v '^$$' | while read -r pattern; do \
	    find . -path "./$$pattern" -exec rm -rf {} +; \
	done