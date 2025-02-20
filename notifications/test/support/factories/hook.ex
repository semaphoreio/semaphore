defmodule Support.Factories.Hook do
  def build do
    InternalApi.RepoProxy.Hook.new(
      hook_id: Ecto.UUID.generate(),
      head_commit_sha: "273b85fbebf7a9493af8c4102d40eb059c9fc6e7",
      commit_message: "Update README.md",
      repo_host_url: "https://github.com/test/test-repo",
      semaphore_email: "test@test.com",
      repo_host_username: "test-username",
      repo_host_email: "test@test.com",
      user_id: Ecto.UUID.generate(),
      git_ref_type: :BRANCH
    )
  end
end
