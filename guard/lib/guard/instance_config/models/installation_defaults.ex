# credo:disable-for-this-file
defmodule Guard.InstanceConfig.Models.InstallationDefaults do
  use Ecto.Schema

  @url_regex ~r/^(http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
  @required_fields [
    :organization_id,
    :installation_id,
    :kube_version,
    :telemetry_endpoint
  ]

  @derive {Jason.Encoder, only: @required_fields}

  @primary_key false
  embedded_schema do
    field(:organization_id, :binary_id)
    field(:installation_id, :binary_id)
    field(:kube_version, :string)
    field(:telemetry_endpoint, :string)
  end

  def changeset(installation_defaults, params) do
    params =
      unless params["kube_version"] do
        Map.put(params, "kube_version", "unspecified")
      else
        params
      end

    installation_defaults
    |> Ecto.Changeset.cast(params, @required_fields)
    |> Ecto.Changeset.validate_required(@required_fields)
    |> Ecto.Changeset.validate_format(:telemetry_endpoint, @url_regex)
  end
end
