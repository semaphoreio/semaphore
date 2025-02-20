defprotocol RepositoryHub.SyncRepositoryAction do
  @spec execute(t, String.t()) :: Toolkit.tupled_result(RepositoryHub.Model.Repositories.t())
  def execute(adapter, repository_id)
end
