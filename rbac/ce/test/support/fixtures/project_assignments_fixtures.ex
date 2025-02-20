defmodule Rbac.Support.ProjectAssignmentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Rbac.Models.ProjectAssignment` module.
  """

  @doc """
  Generate a project_assignment.
  """
  def project_assignment_fixture(attrs \\ %{}) do
    {:ok, project_assignment} =
      attrs
      |> Enum.into(%{
        org_id: Ecto.UUID.generate(),
        project_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate()
      })
      |> Rbac.Models.ProjectAssignment.create()

    project_assignment
  end
end
