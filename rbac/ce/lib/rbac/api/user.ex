defmodule Rbac.Api.User do
  alias InternalApi.User.UserService.Stub
  alias InternalApi.User.{DescribeRequest, DescribeManyRequest, SearchUsersRequest}

  @timeout 30_000

  def get(user_id) do
    channel = channel()
    req = %DescribeRequest{user_id: user_id}

    case Stub.describe(channel, req, timeout: @timeout) do
      {:ok, res} when res.status.code == :OK -> {:ok, res}
      _ -> {:error, "Failed to find the user #{user_id}"}
    end
  end

  def get_many(user_ids) do
    channel = channel()
    req = %DescribeManyRequest{user_ids: user_ids}

    case Stub.describe_many(channel, req, timeout: @timeout) do
      {:ok, res} -> {:ok, res}
      _ -> {:error, "Failed to find the users #{inspect(user_ids)}"}
    end
  end

  @search_users_limit 50
  def search(query) do
    channel = channel()
    req = %SearchUsersRequest{query: query, limit: @search_users_limit}

    case Stub.search_users(channel, req, timeout: @timeout) do
      {:ok, res} -> {:ok, res}
      _ -> {:error, "Failed to search for users with query #{query}"}
    end
  end

  defp channel do
    endpoint = Application.get_env(:rbac, :user_api_grpc_endpoint)
    {:ok, channel} = GRPC.Stub.connect(endpoint)
    channel
  end
end
