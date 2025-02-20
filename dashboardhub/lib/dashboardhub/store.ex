defmodule Dashboardhub.Store do
  require Logger

  alias Dashboardhub.Repo
  alias Dashboardhub.Utils
  import Ecto.Query

  def list(org_id) do
    entries =
      Repo.all(from(s in Repo.Dashboard, where: s.org_id == ^org_id, order_by: s.inserted_at))

    {:ok, entries}
  end

  def update(org_id, dashboard, new_name, new_content) do
    changeset =
      Repo.Dashboard.changeset(dashboard, %{
        name: new_name,
        org_id: org_id,
        content: new_content
      })

    case Repo.update(changeset) do
      {:ok, d} -> {:ok, d}
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def save(org_id, name, content) do
    changeset =
      Repo.Dashboard.changeset(%Repo.Dashboard{}, %{
        name: name,
        org_id: org_id,
        content: content
      })

    case Repo.insert(changeset) do
      {:ok, d} -> {:ok, d}
      {:error, changeset} -> process_save_errors(changeset.errors)
    end
  end

  def get(org_id, id_or_name) do
    dashboard =
      if Utils.uuid?(id_or_name) do
        Repo.get_by(Repo.Dashboard, org_id: org_id, id: id_or_name)
      else
        Repo.get_by(Repo.Dashboard, org_id: org_id, name: id_or_name)
      end

    case dashboard do
      nil -> {:error, :not_found}
      d -> {:ok, d}
    end
  end

  def delete(dashboard) do
    Repo.delete(dashboard)
  end

  def clear! do
    Repo.delete_all(Repo.Dashboard)
  end

  defp process_save_errors([{:unique_names, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  defp process_save_errors([{:name_format, {message, _}} | _]) do
    {:error, :failed_precondition, message}
  end

  defp process_save_errors(_) do
    {:error, :unknown, "Unknown error"}
  end
end
