defmodule Projecthub.Grpc.ProtoCodecTest do
  use ExUnit.Case, async: true

  alias InternalApi.Projecthub.Project
  alias Projecthub.Grpc.ProtoCodec

  @metadata %Project.Metadata{
    name: "renderedtext/test",
    id: "3e4c8a2f-1c5a-4a6b-9a1a-0a0f1b2c3d4e",
    owner_id: "9c2a1e6d-77aa-4f0f-8a0e-2b3c4d5e6f70",
    org_id: "1b0c9d8e-6f50-4a3b-9c2d-1e0f2a3b4c5d",
    description: "a project",
    created_at: %Google.Protobuf.Timestamp{seconds: 1_700_000_000, nanos: 0}
  }

  test "names itself the way the bundled codec does, so the content type matches" do
    assert ProtoCodec.name() == "proto"
    assert ProtoCodec.name() == GRPC.Codec.Proto.name()
  end

  test "round-trips a message, including the bundled Google.Protobuf types" do
    assert @metadata
           |> ProtoCodec.encode()
           |> ProtoCodec.decode(Project.Metadata) == @metadata
  end

  test "reads what the bundled codec encodes" do
    assert @metadata
           |> GRPC.Codec.Proto.encode()
           |> ProtoCodec.decode(Project.Metadata) == @metadata
  end

  test "decodes enum fields to their atom names" do
    decoded =
      %Project.Spec{visibility: :PUBLIC}
      |> ProtoCodec.encode()
      |> ProtoCodec.decode(Project.Spec)

    assert decoded.visibility == :PUBLIC
  end
end
