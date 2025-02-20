defmodule Guard.InstanceConfig.Store do
  import Ecto.Query
  alias Guard.InstanceConfigRepo, as: Repo
  alias Guard.InstanceConfig.Models, as: Models

  def get(type) do
    Models.Config
    |> where([c], c.name == ^(type |> Atom.to_string()))
    |> Repo.one()
    |> case do
      nil -> nil
      config -> config |> Models.Config.decrypt!()
    end
  end

  def set(config) do
    config
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :name)
  end

  def delete(type) do
    Models.Config
    |> where([c], c.name == ^(type |> Atom.to_string()))
    |> Repo.delete_all()
  end
end
