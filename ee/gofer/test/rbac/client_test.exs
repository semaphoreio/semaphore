defmodule Gofer.ClientTest do
  use ExUnit.Case, async: false

  alias Support.Stubs.RBAC, as: RBACStub
  alias Gofer.RBAC.Client
  alias Gofer.RBAC.Subject

  setup_all _ctx do
    RBACStub.setup()

    subject_params = [
      organization_id: UUID.uuid4(),
      project_id: UUID.uuid4(),
      triggerer: UUID.uuid4()
    ]

    role_ids = for _ <- 1..5, do: insert_role(subject_params, UUID.uuid4())
    {:ok, subject: struct(Subject, subject_params), role_ids: role_ids}
  end

  defp insert_role(subject_params, role_id) do
    subject_params
    |> Keyword.values()
    |> List.to_tuple()
    |> Tuple.append(role_id)
    |> RBACStub.set_role()

    role_id
  end

  describe "check_roles/2" do
    @tag capture_log: true
    test "when URL is invalid then returns error", %{subject: subject, role_ids: role_ids} do
      RBACStub.Helpers.set_invalid_url()
      assert {:error, {:timeout, 1_000}} = Client.check_roles(subject, role_ids)
    end

    @tag capture_log: true
    test "when connection times out then returns error", %{subject: subject, role_ids: role_ids} do
      RBACStub.Helpers.set_timeout()
      assert {:error, {:timeout, 1_000}} = Client.check_roles(subject, role_ids)
    end

    test "without any roles", %{subject: subject} do
      assert {:ok, result = %{}} = Client.check_roles(subject, [])
      assert Enum.empty?(result)
    end

    test "with no matching roles", %{subject: subject} do
      checked_roles = for _ <- 1..12, do: UUID.uuid4()

      assert {:ok, result} = Client.check_roles(subject, checked_roles)
      refute result |> Map.values() |> Enum.any?()
    end

    test "with one matching role", %{subject: subject, role_ids: [role_1 | _]} do
      checked_roles = [role_1 | for(_ <- 1..16, do: UUID.uuid4())]

      assert {:ok, result = %{^role_1 => true}} = Client.check_roles(subject, checked_roles)
      refute result |> Map.delete(role_1) |> Map.values() |> Enum.any?()
    end

    test "with three matching roles", %{subject: subject, role_ids: role_ids} do
      existing_roles = Enum.take(role_ids, 3)
      checked_roles = for(_ <- 1..9, do: UUID.uuid4()) ++ existing_roles

      assert {:ok, result} = Client.check_roles(subject, checked_roles)
      assert result |> Map.take(existing_roles) |> Map.values() |> Enum.all?()
      refute result |> Map.drop(existing_roles) |> Map.values() |> Enum.any?()
    end

    test "with all matching roles", %{subject: subject, role_ids: role_ids} do
      assert {:ok, result} = Client.check_roles(subject, role_ids)
      assert result |> Map.values() |> Enum.all?()
    end
  end
end
