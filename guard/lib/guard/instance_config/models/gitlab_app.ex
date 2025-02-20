# credo:disable-for-this-file
defmodule Guard.InstanceConfig.Models.GitlabApp do
  use Ecto.Schema

  @derive {Jason.Encoder,
           only: [
             :client_id,
             :client_secret
           ]}

  @primary_key false
  embedded_schema do
    field(:client_id, :string)
    field(:client_secret, :string)
  end

  def changeset(gitlab_app, params) do
    gitlab_app
    |> Ecto.Changeset.cast(params, [
      :client_id,
      :client_secret
    ])
    |> Ecto.Changeset.validate_required([
      :client_id,
      :client_secret
    ])
  end
end
