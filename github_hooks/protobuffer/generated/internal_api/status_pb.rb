# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: internal_api/status.proto

require 'google/protobuf'

require 'google/rpc/code_pb'


descriptor_data = "\n\x19internal_api/status.proto\x12\x0bInternalApi\x1a\x15google/rpc/code.proto\"9\n\x06Status\x12\x1e\n\x04\x63ode\x18\x01 \x01(\x0e\x32\x10.google.rpc.Code\x12\x0f\n\x07message\x18\x02 \x01(\tb\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module InternalApi
  Status = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.Status").msgclass
end
