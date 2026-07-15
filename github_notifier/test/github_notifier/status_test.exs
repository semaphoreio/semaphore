defmodule GithubNotifier.StatusTest do
  require GrpcMock
  use ExUnit.Case

  alias InternalApi.Repository.CreateBuildStatusRequest

  @repository_id "ee2e6241-f30b-4892-a0d5-bd900b713430"
  @sha "1234567"
  @context "ci/semaphoreci/push: Pipeline"

  setup do
    Cachex.clear(:store)

    test_pid = self()

    GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
      send(test_pid, {:build_status, status_atom(req.status), req.context})
      Google.Protobuf.Empty.new()
    end)

    :ok
  end

  describe ".create" do
    test "does not send pending after success was already sent for the same check" do
      GithubNotifier.Status.create(success_data(), "req-1")
      assert_receive {:build_status, :SUCCESS, @context}

      GithubNotifier.Status.create(pending_data(), "req-2")

      refute_receive {:build_status, :PENDING, _}, 200

      assert Cachex.get!(:store, "#{status_key()}/pending/The build is pending on Semaphore 2.0.") ==
               nil
    end

    test "does not send pending after failure was already sent for the same check" do
      GithubNotifier.Status.create(failure_data(), "req-1")
      assert_receive {:build_status, :FAILURE, @context}

      GithubNotifier.Status.create(pending_data(), "req-2")

      refute_receive {:build_status, :PENDING, _}, 200
    end

    test "sends pending and success in order when they arrive in order" do
      GithubNotifier.Status.create(pending_data(), "req-1")
      GithubNotifier.Status.create(success_data(), "req-2")

      assert_receive {:build_status, :PENDING, @context}
      assert_receive {:build_status, :SUCCESS, @context}
    end

    test "sends pending for a new pipeline after another pipeline's terminal status" do
      GithubNotifier.Status.create(success_data(), "req-1")
      assert_receive {:build_status, :SUCCESS, @context}

      GithubNotifier.Status.create(pending_data(ppl_id: "ppl-2"), "req-2")

      assert_receive {:build_status, :PENDING, @context}
    end

    test "does not send the same status twice" do
      GithubNotifier.Status.create(success_data(), "req-1")
      assert_receive {:build_status, :SUCCESS, @context}

      GithubNotifier.Status.create(success_data(), "req-2")

      refute_receive {:build_status, :SUCCESS, _}, 200
    end
  end

  defp status_atom(status) when is_atom(status), do: status
  defp status_atom(status), do: CreateBuildStatusRequest.Status.key(status)

  defp status_key, do: "#{@repository_id}/#{@sha}/ppl-1/#{@context}"

  defp pending_data(overrides \\ []) do
    data(
      Keyword.merge(
        [state: "pending", description: "The build is pending on Semaphore 2.0."],
        overrides
      )
    )
  end

  defp success_data(overrides \\ []) do
    data(
      Keyword.merge(
        [state: "success", description: "The build passed on Semaphore 2.0."],
        overrides
      )
    )
  end

  defp failure_data(overrides \\ []) do
    data(
      Keyword.merge(
        [state: "failure", description: "The build failed on Semaphore 2.0."],
        overrides
      )
    )
  end

  defp data(overrides) do
    Map.merge(
      %{
        repository_id: @repository_id,
        sha: @sha,
        ppl_id: "ppl-1",
        org_id: "org-1",
        url: "https://example.org/workflows/1",
        context: @context,
        state: "pending",
        description: "The build is pending on Semaphore 2.0."
      },
      Map.new(overrides)
    )
  end
end
