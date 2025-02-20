defmodule Gofer.Deployment.Model.MetricsQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Gofer.Deployment.Model.MetricsQueries
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.EctoRepo

  setup [
    :truncate_database,
    :prepare_params,
    :prepare_database
  ]

  test "count_organizations/0 returns the correct number" do
    assert MetricsQueries.count_organizations() == 2
  end

  test "count_projects/0 returns the correct number" do
    assert MetricsQueries.count_projects() == 4
  end

  test "count_all_targets/0 returns the correct number" do
    assert MetricsQueries.count_all_targets() == 9
  end

  test "count_stuck_targets/0 returns the correct number" do
    assert MetricsQueries.count_stuck_targets() == 2
  end

  test "count_failed_targets/0 returns the correct number" do
    assert MetricsQueries.count_failed_targets() == 1
  end

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployments CASCADE;")
    :ok
  end

  defp prepare_params(_context) do
    {:ok,
     params: %{
       name: "deployment_target",
       description: "Some description",
       url: "https://random.com/url",
       organization_id: UUID.uuid4(),
       project_id: UUID.uuid4(),
       created_by: UUID.uuid4(),
       updated_by: UUID.uuid4(),
       unique_token: UUID.uuid4()
     }}
  end

  defp prepare_database(context) do
    org1_id = UUID.uuid4()
    org2_id = UUID.uuid4()

    insert_deployment_targets(context, 2,
      organization_id: org1_id,
      project_id: UUID.uuid4(),
      state: :SYNCING,
      updated_at: DateTime.utc_now() |> DateTime.add(-120)
    )

    insert_deployment_targets(context, 3,
      organization_id: org1_id,
      project_id: UUID.uuid4(),
      state: :FINISHED,
      result: :SUCCESS
    )

    insert_deployment_targets(context, 1,
      organization_id: org2_id,
      project_id: UUID.uuid4(),
      state: :FINISHED,
      result: :FAILURE
    )

    insert_deployment_targets(context, 3,
      organization_id: org2_id,
      project_id: UUID.uuid4()
    )

    :ok
  end

  defp insert_deployment_targets(context, count, params) do
    for i <- 1..count do
      params =
        context.params
        |> Map.put(:name, "target_#{i}")
        |> Map.put(:unique_token, UUID.uuid4())
        |> Map.merge(Map.new(params))

      %Deployment{}
      |> Deployment.changeset(params)
      |> Ecto.Changeset.cast(params, [:state, :result, :updated_at])
      |> EctoRepo.insert!()
    end
  end
end
