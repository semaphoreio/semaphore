defmodule PreFlightChecks.ProjectPFC.Model.ProjectPFCQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PreFlightChecks.ProjectPFC.Model.ProjectPFCQueries
  setup [:ecto_repo_checkout, :setup_existing_pfc, :setup_pfc_params]

  describe "ProjectPFCQueries.find/1" do
    test "when PPFC doesn't exist then find returns error", ctx do
      assert {:error, {:not_found, project_id}} =
               ProjectPFCQueries.find(ctx[:pfc_params][:project_id])

      assert ^project_id = ctx[:pfc_params][:project_id]
    end

    test "when PPFC exists then find returns ok tuple", ctx do
      assert {:ok, pfc} = ProjectPFCQueries.find(ctx[:existing_pfc].project_id)

      assert pfc.definition.commands == ctx[:existing_pfc].definition.commands
      assert pfc.definition.secrets == ctx[:existing_pfc].definition.secrets
    end
  end

  describe "ProjectPFCQueries.upsert/1" do
    test "when PPFC exists then affects the existing check", ctx do
      modified_params =
        ctx[:pfc_params]
        |> Map.put(:organization_id, ctx[:existing_pfc].organization_id)
        |> Map.put(:project_id, ctx[:existing_pfc].project_id)

      assert {:ok, pfc} = ProjectPFCQueries.upsert(modified_params)
      assert pfc.id == ctx[:existing_pfc].id
      assert pfc.organization_id == ctx[:existing_pfc].organization_id
      assert pfc.project_id == ctx[:existing_pfc].project_id
      assert pfc.inserted_at == ctx[:existing_pfc].inserted_at
    end

    test "when PPFC exists then updates the check", ctx do
      modified_params =
        ctx[:pfc_params]
        |> Map.put(:organization_id, ctx[:existing_pfc].organization_id)
        |> Map.put(:project_id, ctx[:existing_pfc].project_id)

      assert {:ok, pfc} = ProjectPFCQueries.upsert(modified_params)
      assert pfc.definition.commands == ctx[:pfc_params][:definition][:commands]
      assert pfc.definition.secrets == ctx[:pfc_params][:definition][:secrets]
    end

    test "when PPFC doesn't exist then inserts the check", ctx do
      assert {:ok, pfc} = ProjectPFCQueries.upsert(ctx[:pfc_params])
      assert pfc.definition.commands == ctx[:pfc_params][:definition][:commands]
      assert pfc.definition.secrets == ctx[:pfc_params][:definition][:secrets]
    end
  end

  describe "ProjectPFCQueries.remove/1" do
    test "when PPFC exists then deletes the check and returns {:ok, project_id}", ctx do
      project_id = ctx[:existing_pfc].project_id
      assert {:ok, ^project_id} = ProjectPFCQueries.remove(project_id)
      assert {:error, {:not_found, ^project_id}} = ProjectPFCQueries.find(project_id)
    end

    test "when PFC doesn't exist then returns {:ok, project_id}", ctx do
      project_id = ctx[:pfc_params][:project_id]
      assert {:ok, ^project_id} = ProjectPFCQueries.remove(project_id)
    end
  end

  defp ecto_repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PreFlightChecks.EctoRepo)
  end

  defp setup_existing_pfc(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git checkout master",
          "make install"
        ],
        secrets: ["SESSION_SECRET"]
      }
    }

    {:ok, existing_pfc} = ProjectPFCQueries.upsert(params)
    [existing_pfc: existing_pfc]
  end

  defp setup_pfc_params(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git reset --hard HEAD",
          "mix release"
        ],
        secrets: ["DATABASE_PASSWORD"],
        agent: %{
          machine_type: "e2-standard-2",
          os_image: "ubuntu2204"
        }
      }
    }

    [pfc_params: params]
  end
end
