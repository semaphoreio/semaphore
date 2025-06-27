defmodule HooksProcessor.Clients.UserClient do
  @moduledoc """
  Module is used for communication with User service over gRPC.
  """

  alias InternalApi.User.{
    UserService,
    DescribeRequest,
    DescribeByRepositoryProviderRequest,
    DescribeByEmailRequest
  }

  alias Util.{Metrics, ToTuple}
  alias LogTee, as: LT

  defp url, do: Application.get_env(:hooks_processor, :user_api_grpc_url)

  @wormhole_timeout 6_000
  @grpc_timeout 5_000

  # Describe

  def describe(user_id) do
    "user_id: #{user_id}"
    |> LT.debug("Calling User API to find requester")

    Metrics.benchmark("HooksProcessor.UserClient", ["describe"], fn ->
      %DescribeRequest{
        user_id: user_id
      }
      |> do_describe()
    end)
  end

  defp do_describe(request) do
    result =
      Wormhole.capture(__MODULE__, :describe_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> UserService.Stub.describe(request, timeout: @grpc_timeout)
    |> process_describe_response()
  end

  defp process_describe_response({:ok, response}), do: response.user |> ToTuple.ok()
  defp process_describe_response(error = {:error, _msg}), do: error
  defp process_describe_response(error), do: {:error, error}

  # DescribeByRepositoryProvider

  def describe_by_repository_provider(provider_uid, provider_type) do
    Metrics.benchmark("HooksProcessor.UserClient", ["describe_by_repository_provider"], fn ->
      %DescribeByRepositoryProviderRequest{
        provider: %{
          type: provider_type(provider_type),
          uid: provider_uid
        }
      }
      |> do_describe_by_repository_provider()
    end)
  end

  defp provider_type("bitbucket"), do: :BITBUCKET
  defp provider_type("github"), do: :GITHUB
  defp provider_type("gitlab"), do: :GITLAB

  defp do_describe_by_repository_provider(request) do
    result =
      Wormhole.capture(__MODULE__, :describe_by_repository_provider_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_by_repository_provider_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> UserService.Stub.describe_by_repository_provider(request, timeout: @grpc_timeout)
    |> process_describe_by_repository_provider_response()
  end

  defp process_describe_by_repository_provider_response({:ok, user}), do: user |> ToTuple.ok()
  defp process_describe_by_repository_provider_response(error = {:error, _msg}), do: error
  defp process_describe_by_repository_provider_response(error), do: {:error, error}

  # DescribeByEmail

  def describe_by_email(email) do
    Metrics.benchmark("HooksProcessor.UserClient", ["describe_by_email"], fn ->
      %DescribeByEmailRequest{email: email}
      |> do_describe_by_email()
    end)
  end

  defp do_describe_by_email(request) do
    result =
      Wormhole.capture(__MODULE__, :describe_by_email_grpc, [request],
        stacktrace: true,
        timeout: @wormhole_timeout
      )

    case result do
      {:ok, result} -> result
      error -> error
    end
  end

  def describe_by_email_grpc(request) do
    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> UserService.Stub.describe_by_email(request, timeout: @grpc_timeout)
    |> process_describe_by_email_response()
  end

  defp process_describe_by_email_response({:ok, user}), do: user |> ToTuple.ok()
  defp process_describe_by_email_response(error = {:error, _msg}), do: error
  defp process_describe_by_email_response(error), do: {:error, error}
end
