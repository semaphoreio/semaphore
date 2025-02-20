defmodule RepositoryHub.Stub.User do
  @moduledoc false

  alias InternalApi.User.{
    DescribeRequest,
    DescribeResponse,
    GetRepositoryTokenRequest,
    GetRepositoryTokenResponse
  }

  use GRPC.Server, service: InternalApi.User.UserService.Service

  @spec describe(DescribeRequest.t(), any) :: DescribeResponse.t()
  def describe(request, _stream) do
    %DescribeResponse{
      status: "",
      email: "",
      created_at: "",
      avatar_url: "",
      user_id: request.user_id,
      github_token: "",
      github_scope: "",
      github_uid: "",
      name: "",
      github_login: "",
      company: "",
      blocked_at: "",
      repository_scopes: ""
    }
  end

  @spec get_repository_token(GetRepositoryTokenRequest.t(), any) :: GetRepositoryTokenResponse.t()
  def get_repository_token(request, _stream) do
    integration_type =
      request.integration_type
      |> Atom.to_string()
      |> String.downcase()

    token = "#{request.user_id}-#{integration_type}"

    expires_at =
      DateTime.utc_now()
      |> DateTime.to_unix()
      |> then(&%Google.Protobuf.Timestamp{seconds: &1})

    %GetRepositoryTokenResponse{token: token, expires_at: expires_at}
  end
end
