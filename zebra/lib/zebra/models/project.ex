defmodule Zebra.Models.Project do
  defstruct [
    :id,
    :name,
    :private,
    :owner_id,
    :cache_id,
    :git_url,
    :artifact_store_id,
    :org_id,
    :created_at,
    :run_on,
    :forked_pull_requests,
    :public,
    :docker_registry_id,
    :creator_id,
    :repository_id,
    :custom_permissions,
    :debug_permissions,
    :attach_permissions
  ]

  def from_api(raw) do
    %__MODULE__{
      id: raw.metadata.id,
      name: raw.metadata.name,
      owner_id: raw.metadata.owner_id,
      creator_id: raw.metadata.owner_id,
      org_id: raw.metadata.org_id,
      created_at: raw.metadata.created_at,
      private:
        raw.spec.visibility == InternalApi.Projecthub.Project.Spec.Visibility.value(:PRIVATE),
      cache_id: raw.spec.cache_id,
      git_url: raw.spec.repository.url,
      artifact_store_id: raw.spec.artifact_store_id,
      run_on: raw.spec.repository.run_on,
      forked_pull_requests: raw.spec.repository.forked_pull_requests,
      public:
        raw.spec.visibility == InternalApi.Projecthub.Project.Spec.Visibility.value(:PUBLIC),
      docker_registry_id: raw.spec.docker_registry_id,
      repository_id: raw.spec.repository.id,
      custom_permissions: raw.spec.custom_permissions,
      debug_permissions: raw.spec.debug_permissions,
      attach_permissions: raw.spec.attach_permissions
    }
  end
end
