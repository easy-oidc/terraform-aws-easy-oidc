# Copyright 2025 Nadrama Pty Ltd
# SPDX-License-Identifier: Apache-2.0

.PHONY: help tag

help:
	@echo "Available targets:"
	@echo "  tag - Tag the current commit with a version"

tag:
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make tag VERSION=v1.0.0"; \
		exit 1; \
	fi; \
	git tag -a $(VERSION) -m "$(VERSION)"; \
	echo "Tagged $(VERSION)"; \
	echo ""; \
	echo "To push the tag, run:"; \
	echo "  git push origin $(VERSION)"
