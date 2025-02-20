defmodule Secrethub.ProjectSecrets.Mapper do
  alias InternalApi.Secrethub, as: API
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Model

  use Secrethub.LevelGen.Mapper,
    model: Secret,
    level: :PROJECT,
    level_config: :project_config,
    regular_fields: ~w(id name description org_id created_by updated_by)a
end
