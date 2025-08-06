defmodule Rbac.Repo.Migrations.AddSubjectTypeToRoleAssignment do
  use Ecto.Migration

  import Ecto.Query

  def change do
    alter table(:role_assignment) do
      add(:subject_type, :string, default: "user")
    end

    execute(&execute_up/0, &execute_down/0)
  end

  defp execute_up do
    repo().update_all(
      from(r in Rbac.Models.RoleAssignment,
        where: is_nil(r.subject_type)
      ),
      set: [subject_type: "user"]
    )
  end

  defp execute_down, do: :ok
end
