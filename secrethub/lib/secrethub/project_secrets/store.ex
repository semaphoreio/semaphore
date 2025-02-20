defmodule Secrethub.ProjectSecrets.Store do
  use Secrethub.LevelGen.Store, model: Secrethub.ProjectSecrets.Secret
  require Ecto.Query

  def list_by_names(nil, _project_id, _names), do: []
  def list_by_names("", _project_id, _names), do: []
  def list_by_names(_org_id, nil, _names), do: []
  def list_by_names(_org_id, "", _names), do: []
  def list_by_names(_org_id, _project_id, []), do: []

  def list_by_names(org_id, project_id, names) do
    by_project_id(project_id)
    |> Ecto.Query.where([s], s.org_id == ^org_id)
    |> Ecto.Query.where([s], s.name in ^names)
    |> Repo.all()
    |> decrypt_many(false)
  end

  def list_by_project_id(nil, _), do: {:error, :not_found}
  def list_by_project_id("", _), do: {:error, :not_found}

  def list_by_project_id(project_id, ignore_contents) do
    secrets =
      by_project_id(project_id)
      |> Repo.all()
      |> decrypt_many(ignore_contents)

    {:ok, secrets}
  end

  def paginate_by_project_id(nil, _page_size, _page_token), do: {:error, :not_found}
  def paginate_by_project_id("", _page_size, _page_token), do: {:error, :not_found}

  def paginate_by_project_id(project_id, page_size, page_token) do
    page_token = if page_token == "", do: nil, else: page_token

    page =
      by_project_id(project_id)
      |> Ecto.Query.order_by([s], asc: s.name, asc: s.id)
      |> Repo.paginate(cursor_fields: [:name, :id], limit: page_size, after: page_token)

    next_page_token = if is_nil(page.metadata.after), do: "", else: page.metadata.after

    {:ok, decrypt_many(page.entries, false), next_page_token}
  end

  def find_by_name(nil, _project_id, _name), do: {:error, :not_found}
  def find_by_name("", _project_id, _name), do: {:error, :not_found}
  def find_by_name(_org_id, nil, _name), do: {:error, :not_found}
  def find_by_name(_org_id, "", _name), do: {:error, :not_found}
  def find_by_name(_org_id, _project_id, nil), do: {:error, :not_found}
  def find_by_name(_org_id, _project_id, ""), do: {:error, :not_found}

  def find_by_name(org_id, project_id, name) do
    res =
      by_project_id(project_id)
      |> Ecto.Query.where([s], s.org_id == ^org_id)
      |> Ecto.Query.where([s], s.name == ^name)
      |> Repo.one()

    case res do
      nil -> {:error, :not_found}
      secret -> Secrethub.Encryptor.decrypt_secret(secret)
    end
  end

  def destroy_many(project_id) do
    Repo.delete_all(by_project_id(project_id))
  end
end
