defmodule Support.Guard.Store do
  alias Guard.{FrontRepo, Repo}

  def clear! do
    Repo.delete_all(Repo.Collaborator)
    Repo.delete_all(Repo.RbacUser)
    Repo.delete_all(Repo.User)
    Repo.delete_all(Repo.Project)
    Repo.delete_all(Repo.ProjectMember)
    Repo.delete_all(Repo.Suspension)

    FrontRepo.delete_all(FrontRepo.User)
  end
end
