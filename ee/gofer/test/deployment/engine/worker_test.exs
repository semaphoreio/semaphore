defmodule Gofer.Deployment.Engine.WorkerTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Gofer.Deployment.Engine.Supervisor
  alias Gofer.Deployment.Engine.Worker
  alias Gofer.Deployment.Model.Deployment
  alias Support.Stubs.Secrethub, as: SecrethubStub

  alias Gofer.EctoRepo

  @timeout 3_000
  @wait_time 2_500
  @ext_wait_time 7_500

  setup_all do
    GRPC.Server.start(SecrethubMock, 52_051)

    on_exit(fn ->
      GRPC.Server.stop(SecrethubMock)
    end)
  end

  setup do
    SecrethubStub.setup()
  end

  describe "start_link/1" do
    setup [
      :init_context,
      :truncate_database,
      :insert_deployment
    ]

    test "when there are no errors then it is not restarted", ctx do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Worker.start_link(ctx[:deployment_id])
      assert_receive {:EXIT, ^pid, :normal}, @wait_time
    end

    test "when there is no deployment then it is not restarted", _ctx do
      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Worker.start_link(UUID.uuid4())
      assert_receive {:EXIT, ^pid, {:shutdown, :not_found}}, @wait_time
    end

    test "when deployment is already synced then it is not restarted", ctx do
      update_deployment(ctx[:deployment_id], %{
        state: :FINISHED,
        encrypted_secret: nil
      })

      :erlang.process_flag(:trap_exit, true)

      assert {:ok, pid} = Worker.start_link(ctx[:deployment_id])
      assert_receive {:EXIT, ^pid, {:shutdown, :already_synced}}, @wait_time
    end

    test "when there are errors then it is restarted", ctx do
      :erlang.process_flag(:trap_exit, true)
      SecrethubStub.Grpc.expect(:create_encrypted, &error_response/0)

      assert {:ok, pid} = Worker.start_link(ctx[:deployment_id])

      assert_receive {:EXIT, ^pid,
                      {:restart, %{code: :FAILED_PRECONDITION, message: "error has occurred"}}},
                     @ext_wait_time
    end

    test "when there are errors and ttl exceeded then it is not restarted", ctx do
      :erlang.process_flag(:trap_exit, true)
      stale_timestamp = NaiveDateTime.utc_now() |> NaiveDateTime.add(-@timeout)

      update_deployment(ctx[:deployment_id], %{
        inserted_at: stale_timestamp,
        updated_at: stale_timestamp
      })

      SecrethubStub.Grpc.expect(:create_encrypted, &error_response/0)
      assert {:ok, pid} = Worker.start_link(ctx[:deployment_id])
      assert_receive {:EXIT, ^pid, {:shutdown, :ttl_exceeded}}, @wait_time
    end
  end

  describe "handle_info/2" do
    setup [
      :init_context,
      :truncate_database,
      :insert_deployment
    ]

    test "creates a new deployment target secret",
         %{user_id: user_id, organization_id: org_id, deployment_id: dpl_id} do
      update_deployment(dpl_id, %{
        encrypted_secret: encrypted_secret(:create, user_id)
      })

      start_supervised!(Supervisor)
      {:ok, pid} = Supervisor.start_worker(dpl_id)
      ref = Process.monitor(pid)

      if Process.alive?(pid) do
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @wait_time
      end

      assert %{
               id: secret_id,
               name: secret_name,
               action: :create,
               metadata: %{org_id: ^org_id, user_id: ^user_id}
             } = SecrethubStub.get_state()

      assert %Deployment{
               secret_id: ^secret_id,
               secret_name: ^secret_name
             } = EctoRepo.get!(Deployment, dpl_id)

      assert ^secret_name = "DT" <> (dpl_id |> :erlang.md5() |> Base.encode16(case: :lower))
    end

    test "updates an existing deployment target secret",
         %{user_id: user_id, organization_id: org_id, deployment_id: dpl_id} do
      %Deployment{secret_id: secret_id, secret_name: secret_name} =
        update_deployment(dpl_id, %{
          secret_id: UUID.uuid4(),
          secret_name: "DT" <> (dpl_id |> :erlang.md5() |> Base.encode16(case: :lower)),
          encrypted_secret: encrypted_secret(:update, user_id)
        })

      SecrethubStub.set_state(id: secret_id, name: secret_name)

      start_supervised!(Supervisor)
      {:ok, pid} = Supervisor.start_worker(dpl_id)
      ref = Process.monitor(pid)

      if Process.alive?(pid) do
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @wait_time
      end

      assert %{
               id: ^secret_id,
               name: ^secret_name,
               action: :update,
               metadata: %{org_id: ^org_id, user_id: ^user_id}
             } = SecrethubStub.get_state()

      assert %Deployment{
               secret_id: ^secret_id,
               secret_name: ^secret_name
             } = EctoRepo.get!(Deployment, dpl_id)

      assert ^secret_name = "DT" <> (dpl_id |> :erlang.md5() |> Base.encode16(case: :lower))
    end

    test "deletes an existing deployment target secret",
         _ctx = %{user_id: user_id, organization_id: org_id, deployment_id: dpl_id} do
      %Deployment{secret_id: secret_id, secret_name: secret_name} =
        update_deployment(dpl_id, %{
          secret_id: UUID.uuid4(),
          secret_name: "DT" <> (dpl_id |> :erlang.md5() |> Base.encode16(case: :lower)),
          encrypted_secret: encrypted_secret(:delete, user_id)
        })

      start_supervised!(Supervisor)
      {:ok, pid} = Supervisor.start_worker(dpl_id)
      ref = Process.monitor(pid)

      if Process.alive?(pid) do
        assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, @wait_time
      end

      assert %{
               id: ^secret_id,
               name: ^secret_name,
               action: :delete,
               metadata: %{org_id: ^org_id, user_id: ^user_id}
             } = SecrethubStub.get_state()

      assert ^secret_name = "DT" <> (dpl_id |> :erlang.md5() |> Base.encode16(case: :lower))

      assert_raise Ecto.NoResultsError, fn -> EctoRepo.get!(Deployment, dpl_id) end
    end
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp init_context(_context) do
    {:ok, organization_id: UUID.uuid4(), project_id: UUID.uuid4(), user_id: UUID.uuid4()}
  end

  defp insert_deployment(context) do
    %Deployment{id: deployment_id, name: deployment_name} =
      %Deployment{}
      |> Deployment.changeset(%{
        name: "Deployment",
        organization_id: context[:organization_id],
        project_id: context[:project_id],
        created_by: context[:user_id],
        updated_by: context[:user_id],
        unique_token: UUID.uuid4(),
        state: :SYNCING
      })
      |> Deployment.put_encrypted_secret(encrypted_secret(:create))
      |> EctoRepo.insert!()

    {:ok, deployment_id: deployment_id, deployment_name: deployment_name}
  end

  defp update_deployment(deployment_id, changes) do
    Deployment
    |> EctoRepo.get!(deployment_id)
    |> Ecto.Changeset.change(changes)
    |> EctoRepo.update!()
  end

  defp encrypted_secret(request_type, requester_id \\ UUID.uuid4()),
    do: %Deployment.EncryptedSecret{
      request_type: request_type,
      requester_id: requester_id,
      unique_token: UUID.uuid4(),
      key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
      aes256_key: random_payload(256),
      init_vector: random_payload(256),
      payload: random_payload()
    }

  defp random_payload(n_bytes \\ 1_024),
    do: round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()

  defp error_response do
    InternalApi.Secrethub.CreateEncryptedResponse.new(
      metadata:
        InternalApi.Secrethub.ResponseMeta.new(
          status:
            InternalApi.Secrethub.ResponseMeta.Status.new(
              code: :FAILED_PRECONDITION,
              message: "error has occurred"
            )
        )
    )
  end
end
