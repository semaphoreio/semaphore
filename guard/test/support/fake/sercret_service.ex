defmodule Support.Fake.SecretService do
  use GRPC.Server, service: InternalApi.Secrethub.SecretService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end

  def describe_many(req, stream) do
    FunRegistry.run!(__MODULE__, :describe_many, [req, stream])
  end
end
