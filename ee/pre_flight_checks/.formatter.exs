# Used by "mix format"
[
  import_deps: [:ecto, :ecto_sql, :grpc],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"]
]
