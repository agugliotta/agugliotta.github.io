# Makefile for Jekyll Content Creation

# --- Configuration ---
POSTS_DIR := _posts
DRAFTS_DIR := _drafts
# PAGES_DIR can be '.' for root directory, or 'pages', '_pages', etc.
PAGES_DIR := .
# Default shell for commands
SHELL := /bin/bash

# --- Helper Variables ---
# Get current date in YYYY-MM-DD format
CURRENT_DATE := $(shell date +%Y-%m-%d)
# Get current date and time for front matter (compatible format)
# Asegúrate que este formato YYYY-MM-DD HH:MM:SS sea el que Jekyll/tu tema espera.
# Alternativa común ISO 8601 UTC: FULL_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
FULL_DATE := $(shell date +'%Y-%m-%d %H:%M:%S')

# Function to create a URL-friendly slug
# Usage: $(call create_slug, Your Title Here)
define create_slug
$(shell echo "$(1)" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^[:alnum:]]/-/g' -e 's/--+/-/g' -e 's/^-//' -e 's/-$$//')
endef

# --- Targets ---

# Phony targets don't represent files
.PHONY: help post page draft publish serve clean

# Default goal when running 'make' without arguments
.DEFAULT_GOAL := help

post: ## Create a new blog post
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE variable is required."; \
		echo "Usage: make post TITLE=\"Your Post Title\" [LAYOUT=custom] [TAGS=\"t1,t2\"] [CATEGORY=cat]"; \
		exit 1; \
	fi
	$(eval POST_LAYOUT := $(if $(LAYOUT),$(LAYOUT),post))
	$(eval POST_SLUG := $(call create_slug,$(TITLE)))
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
	@# Simplified tags handling
	@echo -n "tags: [" >> "$(POST_FILENAME)"
	$(if $(TAGS),@echo -n "$(shell echo "$(TAGS)" | sed 's/ *, */, /g')" >> "$(POST_FILENAME)")
	@echo "]" >> "$(POST_FILENAME)"
	@echo "---" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "" >> "$(POST_FILENAME)"
	@echo "Post created: $(POST_FILENAME)"

draft: ## Create a new draft post (without date in front matter)
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE variable is required."; \
		echo "Usage: make draft TITLE=\"Your Draft Title\" [LAYOUT=custom] [TAGS=\"t1,t2\"] [CATEGORY=cat]"; \
		exit 1; \
	fi
	$(eval DRAFT_LAYOUT := $(if $(LAYOUT),$(LAYOUT),post))
	$(eval DRAFT_SLUG := $(call create_slug,$(TITLE)))
	$(eval DRAFT_FILENAME := $(DRAFTS_DIR)/$(DRAFT_SLUG).md)
	@mkdir -p $(DRAFTS_DIR)
	@if [ -e "$(DRAFT_FILENAME)" ]; then \
		echo "Error: File '$(DRAFT_FILENAME)' already exists."; \
		exit 1; \
	fi
	@echo "Creating draft: $(DRAFT_FILENAME)"
	@touch "$(DRAFT_FILENAME)"
	@echo "---" >> "$(DRAFT_FILENAME)"
	@echo "layout: $(DRAFT_LAYOUT)" >> "$(DRAFT_FILENAME)"
	@echo "title: \"$(TITLE)\"" >> "$(DRAFT_FILENAME)"
	@# Date is omitted for drafts, will be added upon publishing
	$(if $(CATEGORY),@echo "category: $(CATEGORY)" >> "$(DRAFT_FILENAME)")
	@# Simplified tags handling
	@echo -n "tags: [" >> "$(DRAFT_FILENAME)"
	$(if $(TAGS),@echo -n "$(shell echo "$(TAGS)" | sed 's/ *, */, /g')" >> "$(DRAFT_FILENAME)")
	@echo "]" >> "$(DRAFT_FILENAME)"
	@echo "---" >> "$(DRAFT_FILENAME)"
	@echo "" >> "$(DRAFT_FILENAME)"
	@echo "" >> "$(DRAFT_FILENAME)"
	@echo "" >> "$(DRAFT_FILENAME)"
	@echo "Draft created: $(DRAFT_FILENAME)"

publish: ## Publish a specific draft, adding current date to front matter
	@if [ -z "$(DRAFT_FILE)" ]; then \
		echo "Error: DRAFT_FILE variable is required."; \
		echo "Usage: make publish DRAFT_FILE=\"your-draft-filename.md\""; \
		exit 1; \
	fi
	$(eval SRC_DRAFT := $(DRAFTS_DIR)/$(DRAFT_FILE))
	$(eval DEST_POST := $(POSTS_DIR)/$(CURRENT_DATE)-$(DRAFT_FILE))
	@if ! [ -e "$(SRC_DRAFT)" ]; then \
		echo "Error: Draft file '$(SRC_DRAFT)' not found."; \
		exit 1; \
	fi
	@if [ -e "$(DEST_POST)" ]; then \
		echo "Error: Post file '$(DEST_POST)' already exists."; \
		exit 1; \
	fi
	@mkdir -p $(POSTS_DIR)
	@echo "Publishing '$(SRC_DRAFT)' to '$(DEST_POST)'..."
	@# 1. Mover el archivo
	@mv "$(SRC_DRAFT)" "$(DEST_POST)"
	@echo "Injecting date into front matter of '$(DEST_POST)'..."
	@# 2. Usar sed para insertar la fecha DESPUÉS de la línea 'title:'.
	@#    La opción -i'.bak' es para compatibilidad (crea un backup que luego borramos).
	@#    La 'a\' le dice a sed que añada la línea siguiente después de encontrar el patrón.
	@sed -i'.bak' '/^title: /a\date: $(FULL_DATE)' "$(DEST_POST)"
	@# 3. Eliminar el archivo de backup creado por sed -i
	@rm -f "$(DEST_POST).bak"
	@echo "Draft published successfully with date added: $(DEST_POST)"

page: ## Create a new page
	@if [ -z "$(TITLE)" ]; then \
		echo "Error: TITLE variable is required."; \
		echo "Usage: make page TITLE=\"Your Page Title\" [LAYOUT=custom]"; \
		exit 1; \
	fi
	$(eval PAGE_LAYOUT := $(if $(LAYOUT),$(LAYOUT),page))
	$(eval PAGE_SLUG := $(call create_slug,$(TITLE)))
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
	@echo "permalink: /$(PAGE_SLUG)/" >> "$(PAGE_FILENAME)" # Common practice for pages
	@echo "---" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "# $(TITLE)" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "" >> "$(PAGE_FILENAME)"
	@echo "Page created: $(PAGE_FILENAME)"

serve: ## Test the blog locally including drafts
	bundle exec jekyll serve --trace --livereload --drafts

# Example clean target (customize carefully!)
# clean: ## Remove generated files (example)
# 	@echo "Cleaning generated files..."
# 	rm -rf _site

# --- Self-Documentation ---
help: Makefile ## Display this help message
	@echo "Usage: make [target] [VARIABLE=value ...]"
	@echo ""
	@echo "Targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort
	@echo ""
	@echo "Variables for post/draft:"
	@echo "  TITLE       (Required) The title for the new content."
	@echo "  LAYOUT      (Optional) Custom layout (defaults to 'post')."
	@echo "  TAGS        (Optional) Comma-separated tags. e.g., TAGS=\"a,b,c\""
	@echo "  CATEGORY    (Optional) Single category name."
	@echo ""
	@echo "Variables for page:"
	@echo "  TITLE       (Required) The title for the new page."
	@echo "  LAYOUT      (Optional) Custom layout (defaults to 'page')."
	@echo ""
	@echo "Variables for publish:"
	@echo "  DRAFT_FILE  (Required) The filename of the draft in _drafts (e.g., my-idea.md)."
