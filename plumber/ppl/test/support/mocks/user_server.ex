defmodule Test.Support.Mocks.UserServer do
  use GRPC.Server, service: InternalApi.User.UserService.Service
  alias InternalApi.User.DescribeResponse

  def describe(_request, _stream) do
    %{status: %{code: :OK}, github_login: "github_login"}
    |> Util.Proto.deep_new!(DescribeResponse)
  end
end
