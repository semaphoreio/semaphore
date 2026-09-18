defmodule Projecthub.Grpc.ProtoCodec do
  @moduledoc """
  The "proto" gRPC codec, on protobuf's current API.

  The codec bundled with grpc 0.5.0-beta.1 decodes through
  `Protobuf.Decoder.decode/2`, which protobuf no longer exports. Only the
  decode side differs, and the wire format and the codec name are the same, so
  a client using this codec talks to a server using the bundled one.
  """

  @behaviour GRPC.Codec

  @impl true
  def name, do: "proto"

  @impl true
  def encode(struct), do: Protobuf.Encoder.encode(struct)

  @impl true
  def decode(binary, module), do: Protobuf.decode(binary, module)
end
