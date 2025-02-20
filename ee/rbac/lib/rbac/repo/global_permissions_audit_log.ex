defmodule Rbac.Repo.GlobalPermissionsAuditLog do
  use Rbac.Repo.Schema

  import Ecto.Query, only: [where: 3, first: 2]
  import Rbac.Repo, only: [one: 1, update: 1]

  schema "global_permissions_audit_log" do
    field(:key, :string)
    field(:old_value, :string)
    field(:new_value, :string)
    field(:query_operation, :string)
    field(:notified, :boolean)

    timestamps()
  end

  def load_unprocessed_logs do
    case __MODULE__
         |> where([log], log.notified == ^false)
         |> first(:updated_at)
         |> one() do
      nil ->
        nil

      req ->
        req
    end
  end

  def mark_log_as_notified(%__MODULE__{} = audit_log),
    do: {:ok, _} = audit_log |> fetch() |> changeset(%{notified: true}) |> update()

  defp fetch(%__MODULE__{} = log), do: __MODULE__ |> where([log], log.id == ^log.id) |> one()

  def changeset(%__MODULE__{} = audit_log, attrs \\ %{}) do
    audit_log
    |> cast(attrs, [:notified])
  end
end
