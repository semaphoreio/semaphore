defmodule Rbac.Support.RoleAssignmentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Rbac.Models.RoleAssignment` module.
  """

  @doc """
  Generate a role_assignment.
  """
  def role_assignment_fixture(attrs \\ %{}) do
    {:ok, role_assignment} =
      attrs
      |> Enum.into(%{
        role_id: Ecto.UUID.generate(),
        org_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate()
      })
      |> Rbac.Models.RoleAssignment.create()

    role_assignment
  end
end
