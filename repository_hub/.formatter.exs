ignored_files = [
  "lib/internal_api/**/*"
]

[
  line_length: 120,
  locals_without_parens: [],
  inputs:
    Enum.flat_map(
      ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
      &Path.wildcard(&1, match_dot: true)
    ) -- Enum.flat_map(ignored_files, &Path.wildcard(&1, match_dot: true))
]
