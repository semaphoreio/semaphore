defmodule Gofer.Deployment.Engine.DestroyerTest do
  use ExUnit.Case, async: true

  alias Gofer.Deployment.Engine.Destroyer

  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Deployment.Engine

  setup_all [:prepare_data, :mock_engine]

  setup [:truncate_database, :setup_staging_example, :setup_production_example, :clear_calls]

  test "delete deployment target for a project", ctx do
    event =
      %InternalApi.Projecthub.ProjectDeleted{
        project_id: ctx.project_id
      }
      |> InternalApi.Projecthub.ProjectDeleted.encode()

    Destroyer.handle_message(event)

    assert_worker_started(ctx.prod.id)
    assert_worker_started(ctx.staging.id)
  end

  test "send error metric to watchman on error", ctx do
    mock_watchman()
    set_engine_response({:error, :max_children})

    event =
      %InternalApi.Projecthub.ProjectDeleted{
        project_id: ctx.project_id
      }
      |> InternalApi.Projecthub.ProjectDeleted.encode()

    Destroyer.handle_message(event)

    assert_watched?("Gofer.deployments.destroyer.errors", :count)
  end

  #
  # Helper functions
  #
  defp mock_engine(_context) do
    start_supervised!({Test.MockDynamicSupervisor, [name: Engine.Supervisor]})
    :ok
  end

  defp clear_calls(_context) do
    {:ok, _calls} = Test.MockDynamicSupervisor.clear_calls(Engine.Supervisor)
    :ok
  end

  defp set_engine_response(response) do
    Test.MockDynamicSupervisor.set_response(Engine.Supervisor, response)
    on_exit(fn -> Test.MockDynamicSupervisor.clear_response(Engine.Supervisor) end)
  end

  defp assert_worker_started(deployment_id) do
    {:ok, calls} = Test.MockDynamicSupervisor.get_calls(Engine.Supervisor)

    assert Enum.any?(calls, fn
             {^deployment_id, _pid} -> true
             _ -> false
           end)
  end

  defp mock_watchman do
    watchman_pid = Process.whereis(Watchman.Server)
    Process.unregister(Watchman.Server)
    Process.register(self(), Watchman.Server)

    on_exit(fn ->
      Process.register(watchman_pid, Watchman.Server)
    end)
  end

  defp assert_watched?(metric, type) do
    assert_received {:"$gen_cast", {:send, ^metric, _, ^type}}
  end

  #
  # Setup functions
  #
  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = Gofer.EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp prepare_data(_context) do
    {:ok,
     organization_id: UUID.uuid4(),
     project_id: UUID.uuid4(),
     user_id: UUID.uuid4(),
     role_id: UUID.uuid4(),
     secret_id: UUID.uuid4(),
     target_name: "target name"}
  end

  defp setup_staging_example(context) do
    {:ok,
     staging:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Staging",
         description: "Staging environment",
         url: "https://staging.rtx.com/",
         bookmark_parameter1: "environment",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :FAILURE,
         encrypted_secret: %Deployment.EncryptedSecret{
           request_type: :update,
           requester_id: context[:user_id],
           key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
           unique_token: context[:unique_token],
           aes256_key: random_payload(256),
           init_vector: random_payload(256),
           payload: random_payload(),
           error_message: "{:invalid_params, [:foo, :bar]}"
         },
         secret_id: context[:secret_id],
         secret_name: "Staging secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :USER,
             subject_id: context[:user_id]
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :EXACT,
             pattern: "master"
           }
         ]
       })}
  end

  defp setup_production_example(context) do
    {:ok,
     prod:
       Gofer.EctoRepo.insert!(%Deployment{
         id: Ecto.UUID.generate(),
         name: "Production",
         description: "Production environment",
         url: "https://production.rtx.com",
         bookmark_parameter1: "environment",
         organization_id: context[:organization_id],
         project_id: context[:project_id],
         created_by: context[:user_id],
         updated_by: context[:user_id],
         unique_token: UUID.uuid4(),
         state: :FINISHED,
         result: :SUCCESS,
         secret_id: context[:secret_id],
         secret_name: "Production secret name",
         subject_rules: [
           %Deployment.SubjectRule{
             type: :ROLE,
             subject_id: context[:role_id]
           }
         ],
         object_rules: [
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :REGEX,
             pattern: "release/.*"
           },
           %Deployment.ObjectRule{
             type: :BRANCH,
             match_mode: :EXACT,
             pattern: "master"
           },
           %Deployment.ObjectRule{
             type: :PR,
             match_mode: :ALL,
             pattern: ""
           }
         ]
       })}
  end

  defp random_payload(n_bytes \\ 1_024),
    do: round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()
end
