defmodule Projecthub.Grpc do
  @moduledoc """
  gRPC plumbing shared by every client in this app.
  """

  alias Projecthub.Grpc.ProtoCodec

  @doc """
  Connects to `endpoint` with the codec this app speaks.
  """
  def connect(endpoint), do: GRPC.Stub.connect(endpoint, codec: ProtoCodec)
end
