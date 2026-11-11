# Local only; CI (.github/workflows/build.yaml) uses the same support/ scripts.

SHELL := /bin/bash

FC_REPO ?= https://github.com/firecrawl/firecrawl-mcp-server.git
# Empty = newest stable tag.
FC_REF  ?=

SRC     := src
PATCHES := patches
QUILTRC := $(CURDIR)/.quiltrc
IMAGE   ?= firecrawl-mcp-patched:local
DOCKER_BUILD_ARGS ?=

QUILT_ENV := QUILTRC=$(QUILTRC) QUILT_PATCHES=$(CURDIR)/$(PATCHES)

.DEFAULT_GOAL := help
.PHONY: help prepare-src prepare build smoke refresh clean clean-image

help:
	@echo 'Local patch-authoring / test-build workflow (not used by CI).'
	@echo
	@echo 'Targets:'
	@echo '  prepare-src        clone firecrawl-mcp-server into $(SRC)/ (no patches applied)'
	@echo '  prepare [QUILT=1]  prepare-src + apply $(PATCHES)/series strictly (fuzz=0, same as CI).'
	@echo '                     QUILT=1 prints patch authoring steps.'
	@echo '  build              docker build $(SRC)/ -> $(IMAGE)'
	@echo '  smoke              smoke-test $(IMAGE) (same as CI)'
	@echo '  refresh            re-push every patch with fuzz allowed and quilt-refresh it'
	@echo '                     against the current $(SRC)/ (use after moving to a new FC_REF)'
	@echo '  clean              remove $(SRC)/'
	@echo '  clean-image        remove $(IMAGE)'
	@echo
	@echo 'Variables: FC_REF (default: newest stable tag), FC_REPO, IMAGE (default $(IMAGE)),'
	@echo '           DOCKER_BUILD_ARGS'
	@echo
	@echo 'Patch authoring:  make clean prepare QUILT=1  ->  quilt new/add/edit/refresh (in $(SRC)/)'
	@echo 'New upstream tag: make clean prepare-src FC_REF=vX.Y.Z  ->  make refresh'
	@echo 'Test build:       make prepare build smoke'

$(SRC)/.git:
	@set -e; ref='$(FC_REF)'; \
	if [ -z "$$ref" ]; then ref=$$(FC_REPO='$(FC_REPO)' bash support/latest-tag.sh); fi; \
	echo "Cloning firecrawl-mcp-server $$ref into $(SRC)/"; \
	git clone --depth 1 --branch "$$ref" '$(FC_REPO)' $(SRC)

prepare-src: $(SRC)/.git

prepare: prepare-src
	@bash support/apply-patches.sh $(SRC)
ifeq ($(QUILT),1)
	@echo
	@echo 'Patch authoring (quilt writes straight into $(PATCHES)/):'
	@echo '  export QUILTRC=$(QUILTRC) QUILT_PATCHES=$(CURDIR)/$(PATCHES)'
	@echo '  cd $(SRC)'
	@echo '  quilt new <NNNN-name>.patch ; quilt add <file> ; quilt edit <file> ; quilt refresh'
endif

build:
	@test -d $(SRC) || { echo "No $(SRC)/ -- run 'make prepare' first"; exit 1; }
	docker build -t '$(IMAGE)' $(DOCKER_BUILD_ARGS) $(SRC)

smoke:
	bash support/smoke.sh '$(IMAGE)'

# Push each patch with fuzz allowed and refresh it so it applies with fuzz=0 again.
refresh:
	@test -d $(SRC) || { echo "No $(SRC)/ -- run 'make prepare-src' first"; exit 1; }
	@set -e; \
	if ! grep -qvE '^[[:space:]]*(#|$$)' $(PATCHES)/series; then echo "$(PATCHES)/series is empty -- nothing to refresh."; exit 0; fi; \
	cd $(SRC); export $(QUILT_ENV); \
	quilt pop -a >/dev/null 2>&1 || true; \
	while :; do \
		rc=0; quilt push --fuzz=2 || rc=$$?; \
		if [ $$rc -eq 2 ]; then break; fi; \
		if [ $$rc -ne 0 ]; then \
			echo "Patch '$$(quilt next)' rejects: fix it with 'quilt push -f', resolve the .rej hunks, 'quilt refresh', then re-run 'make refresh'."; \
			exit 1; \
		fi; \
		quilt refresh; \
	done; \
	echo "All patches refreshed in $(PATCHES)/ -- review and commit."

clean:
	rm -rf $(SRC)

clean-image:
	-docker image rm '$(IMAGE)'
