defmodule Support.Factories.OrgMembership do
  @moduledoc """
  Gives a subject an organization-level role binding, which is what makes it a member
  of that organization. Written against the tables directly, since the roles and scopes
  they hang off have no schema module here.
  """

  alias Guard.Repo

  def insert(subject_id, org_id, opts \\ []) do
    ensure_subject(subject_id, Keyword.get(opts, :type, "user"))

    Repo.query!(
      """
      INSERT INTO subject_role_bindings
        (id, role_id, org_id, project_id, subject_id, binding_source, inserted_at, updated_at)
      VALUES ($1, $2, $3, NULL, $4, 'manually_assigned', now(), now())
      ON CONFLICT DO NOTHING
      """,
      [new_uuid(), uuid(role_id(org_id)), uuid(org_id), uuid(subject_id)]
    )

    :ok
  end

  def remove(subject_id, org_id) do
    Repo.query!(
      "DELETE FROM subject_role_bindings WHERE subject_id = $1 AND org_id = $2",
      [uuid(subject_id), uuid(org_id)]
    )

    :ok
  end

  defp ensure_subject(subject_id, type) do
    Repo.query!(
      """
      INSERT INTO subjects (id, name, type, inserted_at, updated_at)
      VALUES ($1, $2, $3, now(), now())
      ON CONFLICT (id) DO NOTHING
      """,
      [uuid(subject_id), "subject-#{String.slice(subject_id, 0, 8)}", type]
    )
  end

  defp role_id(org_id) do
    case Repo.query!("SELECT id FROM rbac_roles LIMIT 1") do
      %{rows: [[id]]} -> Ecto.UUID.load!(id)
      _ -> create_role(org_id)
    end
  end

  defp create_role(org_id) do
    id = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO rbac_roles (id, name, org_id, scope_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, now(), now())
      """,
      [
        uuid(id),
        "member-#{System.unique_integer([:positive])}",
        uuid(org_id),
        uuid(scope_id())
      ]
    )

    id
  end

  defp scope_id do
    %{rows: [[id]]} =
      Repo.query!(
        """
        INSERT INTO scopes (id, scope_name) VALUES ($1, 'org_scope')
        ON CONFLICT (scope_name) DO UPDATE SET scope_name = EXCLUDED.scope_name
        RETURNING id
        """,
        [new_uuid()]
      )

    Ecto.UUID.load!(id)
  end

  defp new_uuid, do: Ecto.UUID.generate() |> Ecto.UUID.dump!()

  defp uuid(value), do: Ecto.UUID.dump!(value)
end
