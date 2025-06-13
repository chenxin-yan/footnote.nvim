.PHONY: test test-watch lint clean

# Test commands
test:
	@echo "Running all tests..."
	@nvim --headless --noplugin -u NONE -c "lua package.path='lua/?.lua;lua/?/init.lua;'..package.path" -c "luafile tests/test_runner.lua"

# Development commands
lint:
	@echo "Running stylua formatter..."
	@command -v stylua >/dev/null 2>&1 || (echo "❌ stylua not installed! Install with: cargo install stylua --features lua52" && exit 1)
	@stylua --check lua/ tests/ || (echo "❌ Formatting issues found! Run 'make format' to fix." && exit 1)

format:
	@echo "Formatting Lua files..."
	@command -v stylua >/dev/null 2>&1 || (echo "❌ stylua not installed! Install with: cargo install stylua --features lua52" && exit 1)
	@stylua lua/ tests/

clean:
	@echo "Cleaning test artifacts..."
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete

# Help
help:
	@echo "Available commands:"
	@echo "  make test           - Run all tests"
	@echo "  make lint           - Check code formatting"
	@echo "  make format         - Format code with stylua"
	@echo "  make clean          - Clean test artifacts"
