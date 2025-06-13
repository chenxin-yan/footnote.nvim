.PHONY: test test-watch lint clean

# Test commands
test:
	@echo "Running all tests..."
	@nvim --headless --noplugin -u NONE -c "lua package.path='lua/?.lua;lua/?/init.lua;'..package.path" -c "luafile tests/test_runner.lua"

test-watch:
	@echo "Watching for changes and running tests..."
	@fswatch -o lua/ tests/ | xargs -n1 -I{} make test

# Development commands
lint:
	@echo "Running stylua formatter..."
	@stylua --check lua/ tests/ || echo "stylua not installed or formatting issues found"

format:
	@echo "Formatting Lua files..."
	@stylua lua/ tests/

clean:
	@echo "Cleaning test artifacts..."
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete

# Help
help:
	@echo "Available commands:"
	@echo "  make test           - Run all tests"
	@echo "  make test-unit      - Run unit tests only"
	@echo "  make test-integration - Run integration tests only"
	@echo "  make test-watch     - Watch files and run tests on changes"
	@echo "  make lint           - Check code formatting"
	@echo "  make format         - Format code with stylua"
	@echo "  make clean          - Clean test artifacts"