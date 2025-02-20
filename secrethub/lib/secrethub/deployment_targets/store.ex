defmodule Secrethub.DeploymentTargets.Store do
  use Secrethub.LevelGen.Store, model: Secrethub.DeploymentTargets.Secret

  def list_by_names(nil, _names), do: []
  def list_by_names("", _names), do: []
  def list_by_names(_org_id, []), do: []

  def list_by_names(org_id, names) do
    Secret
    |> Ecto.Query.where([s], s.org_id == ^org_id)
    |> Ecto.Query.where([s], s.name in ^names)
    |> Repo.all()
    |> decrypt_many(false)
  end

  def find_by_name(nil, _name), do: {:error, :not_found}
  def find_by_name("", _name), do: {:error, :not_found}
  def find_by_name(_org_id, nil), do: {:error, :not_found}
  def find_by_name(_org_id, ""), do: {:error, :not_found}

  def find_by_name(org_id, name) do
    case Repo.get_by(Secret, name: name, org_id: org_id) do
      nil -> {:error, :not_found}
      secret -> Secrethub.Encryptor.decrypt_secret(secret)
    end
  end

  def find_by_target(nil), do: {:error, :not_found}
  def find_by_target(""), do: {:error, :not_found}

  def find_by_target(dt_id) do
    case Repo.get_by(Secret, dt_id: dt_id) do
      nil -> {:error, :not_found}
      secret -> Secrethub.Encryptor.decrypt_secret(secret)
    end
  end
end
