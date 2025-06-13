# Document with Malformed Footnotes

This document contains various malformed footnote patterns for edge case testing.

## Invalid Patterns

Here are some invalid footnote patterns that should be ignored:

- Missing number: [^] 
- Non-numeric: [^abc]
- Missing closing bracket: [^1
- Missing opening bracket: ^1]
- Empty brackets: []
- Wrong format: (^1)

## Valid Footnotes Mixed In

But this one is valid[^1] and should be found.

And this one too[^2].

## Orphaned References

This footnote[^99] has no corresponding definition.

## Footnote Definitions

[^1]: Valid footnote definition.

[^2]: Another valid definition.

Note: [^99] has no definition, so it's orphaned.