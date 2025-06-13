-- Simple test to verify CI blocking
local test_results = { passed = 0, failed = 0 }

-- Simulate some passing tests
test_results.passed = 5

-- Simulate some failing tests (change to 0 to test success case)
test_results.failed = 0

print("Test Summary:")
print("  Passed: " .. test_results.passed)
print("  Failed: " .. test_results.failed)

if test_results.failed > 0 then
    print("❌ Tests failed - exit code 1")
    vim.cmd('cquit 1')
else
    print("✅ Tests passed - exit code 0")
    vim.cmd('quit 0')
end