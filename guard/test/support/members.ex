defmodule Support.Members do
  import Ecto.Query

  alias Guard.FrontRepo

  @doc """
  Backdates a repo_host_account's updated_at so a revoked row falls outside
  the claim grace period.
  """
  def age_repo_host_account(rha, seconds \\ 3 * 60 * 60) do
    stale = DateTime.utc_now() |> DateTime.add(-seconds) |> DateTime.truncate(:second)

    {1, _} =
      from(r in FrontRepo.RepoHostAccount, where: r.id == ^rha.id)
      |> FrontRepo.update_all(set: [updated_at: stale])

    :ok
  end

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
      authentication_token: id,
      single_org_user: false,
      creation_source: nil
    ]

    params = default |> Keyword.merge(params)
    user = Kernel.struct(FrontRepo.User, params)

    FrontRepo.insert(user)
  end

  @doc """
  Insert an RbacUser + Front User + GitHub RepoHostAccount in one call.

  Returns `{user, rha}`. Override RHA fields via `rha_attrs`.
  """
  def insert_user_with_github_account(rha_attrs \\ []) do
    {:ok, user} = Support.Factories.RbacUser.insert()
    {:ok, _} = insert_user(id: user.id, email: user.email, name: user.name)

    rha_defaults = [
      login: "octocat",
      name: "The Octocat",
      github_uid: "583231",
      user_id: user.id,
      token: "token",
      revoked: false,
      permission_scope: "repo"
    ]

    {:ok, rha} = insert_repo_host_account(Keyword.merge(rha_defaults, rha_attrs))
    {user, rha}
  end

  def valid_expires_at do
    DateTime.utc_now()
    |> DateTime.add(3600)
    |> DateTime.truncate(:second)
  end

  def invalid_expires_at do
    DateTime.utc_now()
    |> DateTime.add(-3600)
    |> DateTime.truncate(:second)
  end
end
