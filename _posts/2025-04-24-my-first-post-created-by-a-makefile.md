---
layout: post
title: "My first post created by a Makefile"
date: 2025-04-24 10:14:28
tags: [ia, makefile]
---

To simplify future post and creations I use IA to create a little Makefile to make it easy and let repetitive.

Tis is the code for anyone interest:

````
# Makefile for Jekyll Content Creation

# --- Configuration ---
POSTS_DIR := _posts
# PAGES_DIR can be '.' for root directory, or 'pages', '_pages', etc.
PAGES_DIR := .
# Default shell for commands
SHELL := /bin/bash

# --- Helper Variables ---
# Get current date in YYYY-MM-DD format
CURRENT_DATE := $(shell date +%Y-%m-%d)
# Get current date and time for front matter (more compatible format - no %z)
FULL_DATE := $(shell date +'%Y-%m-%d %H:%M:%S')
# If the above still fails, try ISO 8601 UTC format:
# FULL_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# --- Targets ---

# Phony targets don't represent files
.PHONY: help post page clean

# Default goal when running 'make' without arguments
.DEFAULT_GOAL := help

# Note: The first simple 'help' target definition has been removed.

post: ## Create a new blog post
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE variable is required."; \
		echo "Usage: make post TITLE=\"Your Post Title\""; \
		exit 1; \
	fi
	$(eval POST_LAYOUT := $(if $(LAYOUT),$(LAYOUT),post))
	$(eval POST_SLUG := $(shell echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^[:alnum:]]/-/g' -e 's/--+/-/g' -e 's/^-//' -e 's/-$$//'))
	$(eval POST_FILENAME := $(POSTS_DIR)/$(CURRENT_DATE)-$(POST_SLUG).md)
	@mkdir -p $(POSTS_DIR)
	@if [ -e "$(POST_FILENAME)" ]; then \
		echo "Error: File '$(POST_FILENAME)' already exists."; \
		exit 1; \
	fi
	@echo "Creating post: $(POST_FILENAME)"
	@touch "$(POST_FILENAME)"
	@echo "---" >> "$(POST_FILENAME)"
	@echo "layout: $(POST_LAYOUT)" >> "$(POST_FILENAME)"
	@echo "title: \"$(TITLE)\"" >> "$(POST_FILENAME)"
	@echo "date: $(FULL_DATE)" >> "$(POST_FILENAME)"
	$(if $(CATEGORY),@echo "category: $(CATEGORY)" >> "$(POST_FILENAME)")
	@# Simplified tags handling: write start, conditionally write content, write end.
	@echo -n "tags: [" >> "$(POST_FILENAME)" # -n prevents adding a newline
	$(if $(TAGS),@echo -n "$(shell echo "$(TAGS)" | sed 's/ *, */, /g')" >> "$(POST_FILENAME)")
	@echo "]" >> "$(POST_FILENAME)"
	@echo "---" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "Post created: $(POST_FILENAME)"


page: ## Create a new page
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE variable is required."; \
		echo "Usage: make page TITLE=\"Your Page Title\""; \
		exit 1; \
	fi
	$(eval PAGE_LAYOUT := $(if $(LAYOUT),$(LAYOUT),page))
	$(eval PAGE_SLUG := $(shell echo "$(TITLE)" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^[:alnum:]]/-/g' -e 's/--+/-/g' -e 's/^-//' -e 's/-$$//'))
	# Corrected permalink path construction in page target
	$(eval PAGE_FILENAME := $(PAGES_DIR)/$(PAGE_SLUG).md)
	# Ensure PAGES_DIR exists if it's not '.'
	@if [ "$(PAGES_DIR)" != "." ]; then mkdir -p $(PAGES_DIR); fi
	@if [ -e "$(PAGE_FILENAME)" ]; then \
		echo "Error: File '$(PAGE_FILENAME)' already exists."; \
		exit 1; \
	fi
	@echo "Creating page: $(PAGE_FILENAME)"
	@touch "$(PAGE_FILENAME)"
	@echo "---" >> "$(PAGE_FILENAME)"
	@echo "layout: $(PAGE_LAYOUT)" >> "$(PAGE_FILENAME)"
	@echo "title: \"$(TITLE)\"" >> "$(PAGE_FILENAME)"
	# Corrected variable reference for permalink
	@echo "permalink: /$(PAGE_SLUG)/" >> "$(PAGE_FILENAME)" # Common practice for pages
	@echo "---" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "# $(TITLE)" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "Page created: $(PAGE_FILENAME)"

# Example of a potential 'clean' target (use with caution)
# clean: ## Remove generated files (example, customize carefully!)
# 	@echo "Cleaning generated files..."
# 	# Add commands to remove build artifacts, e.g., rm -rf _site

# --- Self-Documentation ---
# This part generates the help message by parsing comments starting with ##
help: Makefile ## Display this help message
	@echo "Usage: make [target] [VARIABLE=value ...]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@echo ""
	@echo "Variables:"
	@echo "  TITLE     (Required for post/page) The title for the new content."
	@echo "  LAYOUT    (Optional) Custom layout (defaults to 'post' or 'page')."
	@echo "  TAGS      (Optional, post only) Comma-separated tags. e.g., TAGS=\"a,b,c\""
	@echo "  CATEGORY  (Optional, post only) Single category name."
```




