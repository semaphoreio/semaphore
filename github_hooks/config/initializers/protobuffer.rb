# Protobuffer files are generated with class names that don't match the file name.
# To avoid Rails loading issues, we generate the protobuffer files outside of the
# app and lib repositories and instead use the protobuffer directory in the root
# of this repository.
#
# Then, when the files are generated, we load them in the Rails initialization
# process.

require "grpc"
require "google/protobuf"

# Generated protobuf files require nested files using paths like
# `internal_api/response_status_pb`, so make the generated root resolvable.
generated_path = Rails.root.join("protobuffer/generated").to_s
$LOAD_PATH.unshift(generated_path) unless $LOAD_PATH.include?(generated_path)

Dir["protobuffer/generated/*.rb"].each { |file| require_relative "../../#{file}" }
Dir["protobuffer/generated/semaphore/*.rb"].each { |file| require_relative "../../#{file}" }
