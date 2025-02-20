defmodule PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PreFlightChecks.OrganizationPFC.Model.OrganizationPFCQueries
  setup [:ecto_repo_checkout, :setup_existing_pfc, :setup_pfc_params]

  describe "OrganizationPFCQueries.find/1" do
    test "when OPFC doesn't exist then find returns error", ctx do
      assert {:error, {:not_found, organization_id}} =
               OrganizationPFCQueries.find(ctx[:pfc_params][:organization_id])

      assert ^organization_id = ctx[:pfc_params][:organization_id]
    end

    test "when OPFC exists then find returns ok tuple", ctx do
      assert {:ok, pfc} = OrganizationPFCQueries.find(ctx[:existing_pfc].organization_id)

      assert pfc.definition.commands == ctx[:existing_pfc].definition.commands
      assert pfc.definition.secrets == ctx[:existing_pfc].definition.secrets
    end
  end

  describe "OrganizationPFCQueries.upsert/1" do
    test "when OPFC exists then affects the existing check", ctx do
      modified_params =
        ctx[:pfc_params]
        |> Map.put(:organization_id, ctx[:existing_pfc].organization_id)

      assert {:ok, pfc} = OrganizationPFCQueries.upsert(modified_params)
      assert pfc.id == ctx[:existing_pfc].id
      assert pfc.organization_id == ctx[:existing_pfc].organization_id
      assert pfc.inserted_at == ctx[:existing_pfc].inserted_at
    end

    test "when OPFC exists then updates the check", ctx do
      modified_params =
        ctx[:pfc_params]
        |> Map.put(:organization_id, ctx[:existing_pfc].organization_id)

      assert {:ok, pfc} = OrganizationPFCQueries.upsert(modified_params)
      assert pfc.definition.commands == ctx[:pfc_params][:definition][:commands]
      assert pfc.definition.secrets == ctx[:pfc_params][:definition][:secrets]
    end

    test "when OPFC doesn't exist then inserts the check", ctx do
      assert {:ok, pfc} = OrganizationPFCQueries.upsert(ctx[:pfc_params])
      assert pfc.definition.commands == ctx[:pfc_params][:definition][:commands]
      assert pfc.definition.secrets == ctx[:pfc_params][:definition][:secrets]
    end
  end

  describe "OrganizationPFCQueries.remove/1" do
    test "when OPFC exists then deletes the check", ctx do
      organization_id = ctx[:existing_pfc].organization_id
      assert {:ok, ^organization_id} = OrganizationPFCQueries.remove(organization_id)

      assert {:error, {:not_found, ^organization_id}} =
               OrganizationPFCQueries.find(organization_id)
    end

    test "when PFC doesn't exist then returns error tuple", ctx do
      organization_id = ctx[:pfc_params][:organization_id]
      assert {:ok, ^organization_id} = OrganizationPFCQueries.remove(organization_id)
    end
  end

  defp ecto_repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PreFlightChecks.EctoRepo)
  end

  defp setup_existing_pfc(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git checkout master",
          "make install"
        ],
        secrets: ["SESSION_SECRET"]
      }
    }

    {:ok, existing_pfc} = OrganizationPFCQueries.upsert(params)
    [existing_pfc: existing_pfc]
  end

  defp setup_pfc_params(_context) do
    params = %{
      organization_id: UUID.uuid4(),
      requester_id: UUID.uuid4(),
      definition: %{
        commands: [
          "git reset --hard HEAD",
          "mix release"
        ],
        secrets: ["DATABASE_PASSWORD"]
      }
    }

    [pfc_params: params]
  end
end
