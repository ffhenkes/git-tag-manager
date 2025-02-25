.PHONY: build clean help

## Display this help message.
help:
	@echo ""
	@echo "Usage: make [TARGET]"
	@echo ""
	@echo "TARGETS:"
	@echo "  build    Clean the dist directory, copy the git_tag_manager.sh file to dist as git-tag-manager,"
	@echo "           set executable permission, and display the resulting structure (if 'tree' is installed)."
	@echo ""
	@echo "  clean    Remove the dist directory and display a cleaning message."
	@echo ""
	@echo "NOTES:"
	@echo "  - The build target depends on clean, ensuring a fresh build."
	@echo "  - If the 'tree' command is not available, its absence will be silently ignored."
	@echo ""

## Remove the dist directory.
clean:
	@rm -rf dist
	@echo "Cleaning dist files"

## Build the project by preparing the dist directory and copying the script.
build: clean
	@mkdir -p dist
	@cp git_tag_manager.sh dist/git-tag-manager
	@chmod +x dist/git-tag-manager
	@echo "A new git-tag-manager is ready!"
	@tree dist || true
