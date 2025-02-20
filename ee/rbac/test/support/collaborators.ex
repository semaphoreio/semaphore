defmodule Support.Collaborators do
  alias Rbac.Repo

  def insert(params) do
    default = [
      project_id: Ecto.UUID.generate(),
      github_username: "zack",
      github_uid: Ecto.UUID.generate(),
      admin: true,
      push: true,
      pull: true
    ]

    params = default |> Keyword.merge(params)
    collaborator = Kernel.struct(Repo.Collaborator, params)

    Repo.insert(collaborator)
  end

  def insert_admin(params),
    do: insert(params |> Keyword.merge(admin: true, push: true, pull: true))

  def insert_writer(params),
    do: insert(params |> Keyword.merge(admin: false, push: true, pull: true))

  def insert_reader(params),
    do: insert(params |> Keyword.merge(admin: false, push: false, pull: true))

  def insert_user(params) do
    default = [
      user_id: Ecto.UUID.generate(),
      github_uid: Ecto.UUID.generate(),
      provider: "github"
    ]

    params = default |> Keyword.merge(params)
    user = Kernel.struct(Repo.User, params)

    Repo.insert(user)
  end
end
