# credo:disable-for-this-file
defmodule Guard.InstanceConfig.Models.GithubApp do
  use Ecto.Schema

  @derive {Jason.Encoder,
           only: [
             :app_id,
             :slug,
             :name,
             :client_id,
             :client_secret,
             :pem,
             :webhook_secret,
             :html_url
           ]}

  @primary_key false
  embedded_schema do
    field(:app_id, :string)
    field(:slug, :string)
    field(:name, :string)
    field(:client_id, :string)
    field(:client_secret, :string)
    field(:pem, :string)
    field(:webhook_secret, :string)
    field(:html_url, :string)
  end

  def changeset(git_app, params) do
    git_app
    |> Ecto.Changeset.cast(params, [
      :app_id,
      :slug,
      :name,
      :client_id,
      :client_secret,
      :pem,
      :webhook_secret,
      :html_url
    ])
    |> Ecto.Changeset.validate_required([
      :app_id,
      :slug,
      :client_id,
      :client_secret,
      :pem,
      :webhook_secret,
      :html_url
    ])
  end
end
