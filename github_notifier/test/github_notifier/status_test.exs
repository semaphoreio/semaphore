defmodule GithubNotifier.StatusTest do
  use ExUnit.Case

  @repository_id "ee2e6241-f30b-4892-a0d5-bd900b713430"
  @sha "1234567"
  @context "ci/semaphoreci/push: Pipeline"

  setup do
    Cachex.clear(:store)

    test_pid = self()

    GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
      send(test_pid, {:build_status, req.status, req.context})
      Support.Factories.create_build_status_response()
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

    test "a delivery queued behind a slow one completes and stays ordered" do
      test_pid = self()

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
        status = req.status
        send(test_pid, {:build_status_started, status})

        if status == :PENDING, do: :timer.sleep(300)

        send(test_pid, {:build_status, status, req.context})
        Support.Factories.create_build_status_response()
      end)

      slow = Task.async(fn -> GithubNotifier.Status.create(pending_data(), "req-1") end)
      assert_receive {:build_status_started, :PENDING}, 2_000

      queued = Task.async(fn -> GithubNotifier.Status.create(success_data(), "req-2") end)

      assert Task.await(slow) == :ok
      assert Task.await(queued) == :ok

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

    test "raises and does not mark the status as sent when delivery fails" do
      endpoint = Application.fetch_env!(:github_notifier, :repositoryhub_api_grpc_endpoint)

      on_exit(fn ->
        Application.put_env(:github_notifier, :repositoryhub_api_grpc_endpoint, endpoint)
      end)

      Application.put_env(:github_notifier, :repositoryhub_api_grpc_endpoint, "127.0.0.1:1")

      assert_raise RuntimeError, ~r/Failed to deliver success status/, fn ->
        GithubNotifier.Status.create(success_data(), "req-1")
      end

      assert Cachex.get!(:store, "#{status_key()}/success/The build passed on Semaphore 2.0.") ==
               nil

      assert Cachex.get!(:store, "terminal/#{status_key()}") == nil

      Application.put_env(:github_notifier, :repositoryhub_api_grpc_endpoint, endpoint)

      GithubNotifier.Status.create(success_data(), "req-2")
      assert_receive {:build_status, :SUCCESS, @context}
    end

    test "raises and does not mark the status as sent when repositoryhub replies with a non-OK code" do
      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn _req, _stream ->
        Support.Factories.create_build_status_response(:SERVICE_ERROR)
      end)

      assert_raise RuntimeError, ~r/Failed to deliver success status/, fn ->
        GithubNotifier.Status.create(success_data(), "req-1")
      end

      assert Cachex.get!(:store, "#{status_key()}/success/The build passed on Semaphore 2.0.") ==
               nil

      assert Cachex.get!(:store, "terminal/#{status_key()}") == nil
    end

    test "raises and does not mark the status as sent when the RPC fails" do
      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn _req, _stream ->
        raise GRPC.RPCError,
          status: GRPC.Status.unavailable(),
          message: "repositoryhub is unavailable"
      end)

      assert_raise RuntimeError, ~r/Failed to deliver success status/, fn ->
        GithubNotifier.Status.create(success_data(), "req-1")
      end

      assert Cachex.get!(:store, "#{status_key()}/success/The build passed on Semaphore 2.0.") ==
               nil

      assert Cachex.get!(:store, "terminal/#{status_key()}") == nil
    end

    test "sends the pipeline id as source_id" do
      test_pid = self()

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
        send(test_pid, {:source_id, req.source_id})
        Support.Factories.create_build_status_response()
      end)

      GithubNotifier.Status.create(success_data(), "req-1")

      assert_receive {:source_id, "ppl-1"}
    end

    test "delivers remaining statuses when an earlier one in the list fails" do
      test_pid = self()
      block_context = "ci/semaphoreci/push: Block A"

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn req, _stream ->
        if req.context == block_context do
          Support.Factories.create_build_status_response(:SERVICE_ERROR)
        else
          send(test_pid, {:build_status, req.status, req.context})
          Support.Factories.create_build_status_response()
        end
      end)

      statuses = [
        success_data(context: block_context, description: "Block A passed"),
        success_data()
      ]

      assert_raise RuntimeError, ~r/Failed to deliver 1 of 2 statuses/, fn ->
        GithubNotifier.Status.create(statuses, "req-1")
      end

      assert_receive {:build_status, :SUCCESS, @context}
    end

    test "treats a delivery skipped by the server-side guard as delivered" do
      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn _req, _stream ->
        struct(InternalApi.Repository.CreateBuildStatusResponse, code: :OK, skipped: true)
      end)

      assert :ok = GithubNotifier.Status.create(pending_data(), "req-1")

      assert Cachex.get!(
               :store,
               "#{status_key()}/pending/The build is pending on Semaphore 2.0."
             ) == true
    end
  end

  describe "connection reuse" do
    test "reuses the gRPC connection across deliveries" do
      GithubNotifier.Status.create(pending_data(), "req-1")
      assert_receive {:build_status, :PENDING, @context}

      pid = conn_pid(status_key())
      assert Process.alive?(pid)

      GithubNotifier.Status.create(success_data(), "req-2")
      assert_receive {:build_status, :SUCCESS, @context}

      assert conn_pid(status_key()) == pid
    end

    test "reconnects when the cached connection is down" do
      GithubNotifier.Status.create(pending_data(), "req-1")
      assert_receive {:build_status, :PENDING, @context}

      pid = conn_pid(status_key())
      Process.exit(pid, :kill)

      GithubNotifier.Status.create(success_data(), "req-2")
      assert_receive {:build_status, :SUCCESS, @context}

      new_pid = conn_pid(status_key())
      assert new_pid != pid
      assert Process.alive?(new_pid)
    end

    test "keeps the connection after a non-OK response" do
      GithubNotifier.Status.create(pending_data(), "req-1")
      assert_receive {:build_status, :PENDING, @context}

      pid = conn_pid(status_key())

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn _req, _stream ->
        Support.Factories.create_build_status_response(:SERVICE_ERROR)
      end)

      assert_raise RuntimeError, ~r/Failed to deliver success status/, fn ->
        GithubNotifier.Status.create(success_data(), "req-2")
      end

      assert conn_pid(status_key()) == pid
      assert Process.alive?(pid)
    end

    test "drops the connection after a transport error" do
      GithubNotifier.Status.create(pending_data(), "req-1")
      assert_receive {:build_status, :PENDING, @context}

      assert conn_pid(status_key())

      GrpcMock.stub(RepositoryHubMock, :create_build_status, fn _req, _stream ->
        raise GRPC.RPCError,
          status: GRPC.Status.unavailable(),
          message: "repositoryhub is unavailable"
      end)

      assert_raise RuntimeError, ~r/Failed to deliver success status/, fn ->
        GithubNotifier.Status.create(success_data(), "req-2")
      end

      worker = GithubNotifier.StatusSender.worker_for(status_key())
      assert :sys.get_state(worker).channel == nil
    end
  end

  defp conn_pid(status_key) do
    worker = GithubNotifier.StatusSender.worker_for(status_key)

    %{channel: %{adapter_payload: %{conn_pid: pid}}} = :sys.get_state(worker)

    pid
  end

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
