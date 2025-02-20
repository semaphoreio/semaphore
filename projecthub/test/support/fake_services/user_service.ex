defmodule Support.FakeServices.UserService do
  @moduledoc false

  use GRPC.Server, service: InternalApi.User.UserService.Service

  def describe(req, stream) do
    FunRegistry.run!(__MODULE__, :describe, [req, stream])
  end
end
