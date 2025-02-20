defmodule Secrethub.DeploymentTargets.Mapper do
  alias InternalApi.Secrethub, as: API
  alias Secrethub.DeploymentTargets.Secret
  alias Secrethub.Model

  use Secrethub.LevelGen.Mapper,
    model: Secret,
    level: :DEPLOYMENT_TARGET,
    level_config: :dt_config,
    regular_fields: ~w(id name org_id created_by updated_by)a
end
