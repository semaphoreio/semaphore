defmodule Support.Members do
  alias Rbac.FrontRepo

  def insert_member(params) do
    default = [
      github_username: "frank",
      github_uid: Ecto.UUID.generate(),
      organization_id: Ecto.UUID.generate(),
      repo_host: "github"
    ]

    params = default |> Keyword.merge(params)
    member = Kernel.struct(FrontRepo.Member, params)

    FrontRepo.insert(member)
  end

  def insert_repo_host_account(params) do
    default = [
      login: "",
      github_uid: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      repo_host: "github"
    ]

    params = default |> Keyword.merge(params)
    rha = Kernel.struct(FrontRepo.RepoHostAccount, params)

    FrontRepo.insert(rha)
  end

  def insert_user(params) do
    id = Ecto.UUID.generate()

    default = [
      id: id,
      name: "",
      email: "#{id}@example.com",
      authentication_token: id
    ]

    params = default |> Keyword.merge(params)
    user = Kernel.struct(FrontRepo.User, params)

    FrontRepo.insert(user)
  end
end
