defmodule Guard.Store.Suspension do
  require Logger

  alias Guard.Repo
  import Ecto.Query

  def exists?(org_id) do
    case Repo.Suspension |> where(org_id: ^org_id) |> first |> Repo.one() do
      nil -> false
      _ -> true
    end
  end

  def remove(org_id) do
    Repo.Suspension |> where(org_id: ^org_id) |> Repo.delete_all()

    :ok
  end

  def add(org_id) do
    changeset =
      Repo.Suspension.changeset(%Repo.Suspension{}, %{
        org_id: org_id
      })

    case Repo.insert(changeset) do
      {:ok, s} -> {:ok, s}
      e -> e
    end
  end
end
