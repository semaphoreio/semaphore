# Standalone Gemfile used ONLY by the `grpc-gem` build stage in ../Dockerfile.
#
# Its sole job is to compile the forked grpc C-core (clone + submodule init +
# native build) exactly once into a cacheable Docker layer. Because this stage's
# cache key is *this file* (not the full Gemfile.lock), unrelated gem bumps no
# longer trigger the ~20-40 min grpc recompile.
#
# KEEP THIS IN SYNC WITH ../Gemfile and ../Gemfile.lock:
#   - the :ref below must equal the `revision:` of the grpc GIT block in
#     Gemfile.lock (currently d2bfbfab64b64643280a116fc957107db43d7727).
# If it drifts, nothing breaks — the main `bundle install` just recompiles grpc
# that one build instead of reusing the cached layer.
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gem "grpc", "1.62.1",
    :github     => "renderedtext/grpc",
    :ref        => "d2bfbfab64b64643280a116fc957107db43d7727",
    :submodules => true
