defmodule Support.Rbac.Store do
  alias Rbac.Repo
  alias Rbac.FrontRepo

  def clear! do
    Repo.delete_all(Repo.Collaborator)
    Repo.delete_all(Repo.RbacUser)
    Repo.delete_all(Repo.User)
    Repo.delete_all(Repo.Project)

    FrontRepo.delete_all(FrontRepo.User)
  end
end
