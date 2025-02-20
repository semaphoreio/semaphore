# credo:disable-for-this-file
defmodule Guard.InstanceConfig.Models.BitbucketApp do
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

  def changeset(bitbucket_app, params) do
    bitbucket_app
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
