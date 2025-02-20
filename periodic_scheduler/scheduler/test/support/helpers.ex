defmodule Test.Helpers do
  @moduledoc """
    Helper functions for tests.
  """

  use ExUnit.Case

  def truncate_db do
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Scheduler.PeriodicsRepo, "truncate table periodics cascade;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(
               Scheduler.PeriodicsRepo,
               "truncate table delete_requests cascade;"
             )

    # Test implementation of FrontDB
    assert {:ok, _} =
             Ecto.Adapters.SQL.query(Scheduler.FrontRepo, "truncate table projects cascade;")

    assert {:ok, _} =
             Ecto.Adapters.SQL.query(
               Scheduler.FrontRepo,
               "truncate table repo_host_accounts cascade;"
             )
  end

  def seed_front_db() do
    ids = %{
      pr_id: UUID.uuid4(),
      org_id: UUID.uuid4(),
      usr_id: UUID.uuid4(),
      br_id: UUID.uuid4(),
      wf_id: UUID.uuid4(),
      rp_id: UUID.uuid4(),
      rha_id: UUID.uuid4(),
      commit_sha: UUID.uuid4()
    }

    payload = %{head_commit: %{id: ""}, after: ids.commit_sha}
    request = '{"payload": #{inspect(Jason.encode!(payload))}}'

    assert {:ok, _resp} =
             "INSERT INTO projects(id, name, organization_id, creator_id)
      VALUES ('#{ids.pr_id}', 'Project 1', '#{ids.org_id}', '#{ids.usr_id}');"
             |> Scheduler.FrontRepo.query([])

    assert {:ok, _resp} =
             "INSERT INTO branches(id, name, project_id)
      VALUES ('#{ids.br_id}', 'master', '#{ids.pr_id}');"
             |> Scheduler.FrontRepo.query([])

    assert {:ok, _resp} =
             "INSERT INTO workflows(id, branch_id, request, created_at)
      VALUES ('#{ids.wf_id}', '#{ids.br_id}', '#{request}', now());"
             |> Scheduler.FrontRepo.query([])

    assert {:ok, _resp} =
             "INSERT INTO repositories(id, project_id, name, owner)
      VALUES ('#{ids.rp_id}', '#{ids.pr_id}', 'test_repo', 'renderedtext');"
             |> Scheduler.FrontRepo.query([])

    assert {:ok, _resp} =
             "INSERT INTO repo_host_accounts(id, user_id, token)
      VALUES ('#{ids.rha_id}', '#{ids.usr_id}', 'access_token value');"
             |> Scheduler.FrontRepo.query([])

    ids
  end

  def purge_queue(queue) do
    {:ok, connection} = System.get_env("RABBITMQ_URL") |> AMQP.Connection.open()
    queue_name = "periodic-scheduler.#{queue}"
    {:ok, channel} = AMQP.Channel.open(connection)

    AMQP.Queue.declare(channel, queue_name, durable: true)

    AMQP.Queue.purge(channel, queue_name)

    AMQP.Connection.close(connection)
  end
end
