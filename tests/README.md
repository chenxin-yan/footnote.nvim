# Testing for footnote.nvim

This directory contains the test suite for the footnote.nvim plugin.

## Test Structure

```
tests/
├── spec/
│   ├── unit/           # Unit tests for individual modules
│   │   ├── utils_spec.lua
│   │   └── config_spec.lua
│   └── integration/    # Integration tests for complete workflows
│       ├── operations_spec.lua
│       └── navigation_spec.lua
├── fixtures/           # Sample data for testing
│   ├── sample_markdown.md
│   ├── empty_document.md
│   └── malformed_footnotes.md
├── test_runner.lua     # Main test runner
└── README.md          # This file
```

## Running Tests

### Prerequisites

1. **Neovim**: Make sure you have Neovim installed (version 0.8.0 or later recommended)
2. **plenary.nvim**: Install plenary.nvim for testing utilities:
   ```bash
   # Using vim-plug
   Plug 'nvim-lua/plenary.nvim'
   
   # Using packer
   use 'nvim-lua/plenary.nvim'
   ```

### Running All Tests

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Run only integration tests  
make test-integration
```

### Running Individual Test Files

```bash
# Run a specific test file
nvim --headless -c "luafile tests/spec/unit/utils_spec.lua" -c "qa!"

# Run test with the test runner
nvim -l tests/test_runner.lua
```

### Continuous Testing

```bash
# Watch files and run tests on changes (requires fswatch)
make test-watch
```

## Test Types

### Unit Tests

Unit tests focus on testing individual functions in isolation:

- **utils_spec.lua**: Tests utility functions like `get_next_footnote_number`, `get_word_end`, `is_on_ref`
- **config_spec.lua**: Tests configuration setup, keymaps, and autocmds

Unit tests use mocked vim API calls to ensure isolation and consistency.

### Integration Tests

Integration tests test complete workflows with real buffer operations:

- **operations_spec.lua**: Tests footnote creation, navigation between references and content
- **navigation_spec.lua**: Tests moving between footnote references (next/previous)

Integration tests use mocked vim API but simulate real buffer state changes.

## Test Fixtures

Sample markdown files in `fixtures/` provide realistic test data:

- **sample_markdown.md**: Complete document with various footnote scenarios
- **empty_document.md**: Document without footnotes for testing creation
- **malformed_footnotes.md**: Edge cases with invalid footnote patterns

## Writing New Tests

### Unit Test Example

```lua
describe("my_module", function()
  it("should do something", function()
    local result = my_module.my_function(input)
    assert.are.equal(expected, result)
  end)
end)
```

### Integration Test Example

```lua
describe("my_integration", function()
  before_each(function()
    -- Set up test state
    current_buffer_lines = {"test content"}
    cursor_position = {1, 0}
  end)
  
  it("should perform workflow", function()
    my_module.my_function()
    -- Assert expected state changes
    assert.are.equal("expected content", current_buffer_lines[1])
  end)
end)
```

## Test Frameworks

The test suite supports multiple test frameworks:

1. **busted** - Full-featured Lua testing framework (recommended)
2. **plenary.nvim** - Neovim-specific testing utilities  
3. **Standalone** - Simple built-in test runner for basic assertions

## CI/CD

Tests run automatically on:
- Push to main/develop branches
- Pull requests to main
- Multiple Neovim versions (stable, nightly, v0.8.0)

See `.github/workflows/test.yml` for CI configuration.

## Troubleshooting

### Tests not running
- Ensure plenary.nvim is installed
- Check that Neovim can find the lua modules
- Verify test file syntax with `nvim --headless -c "luafile path/to/test.lua"`

### Mock API issues
- Make sure mock vim API covers all functions used by your code
- Check that mock state is properly reset between tests

### CI failures
- Test with the specific Neovim version that's failing
- Check that all dependencies are available in CI environment