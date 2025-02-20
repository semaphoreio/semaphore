defmodule Secrethub.ProjectSecrets.PublicAPIMapper do
  alias Semaphore.ProjectSecrets.V1, as: API
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Model

  # encoders

  def encode(secrets, render_content) when is_list(secrets),
    do: Enum.map(secrets, encoder(render_content))

  def encode(secret = %Secret{}, render_content) do
    API.Secret.new(
      metadata:
        API.Secret.Metadata.new(
          id: secret.id,
          name: secret.name,
          create_time: secret.inserted_at && encode(secret.inserted_at),
          update_time: secret.updated_at && encode(secret.updated_at),
          checkout_at: secret.used_at && encode(secret.used_at),
          project_id_or_name: secret.project_id,
          content_included: render_content
        ),
      data: secret.content && encode(secret.content, render_content)
    )
  end

  def encode(content = %Model.Content{}, render_content) do
    API.Secret.Data.new(
      env_vars: Enum.into(content.env_vars, [], encoder(render_content)),
      files: Enum.into(content.files, [], encoder(render_content))
    )
  end

  def encode(env_var = %Model.EnvVar{}, _render_content = true),
    do: API.Secret.EnvVar.new(name: env_var.name, value: env_var.value)

  def encode(env_var = %Model.EnvVar{}, _render_content = false),
    do: API.Secret.EnvVar.new(name: env_var.name, value: "")

  def encode(file = %Model.File{}, _render_content = true),
    do: API.Secret.File.new(path: file.path, content: file.content)

  def encode(file = %Model.File{}, _render_content = false),
    do: API.Secret.File.new(path: file.path, content: "")

  def encode(naive_datetime = %NaiveDateTime{}),
    do: naive_datetime |> DateTime.from_naive!("Etc/UTC") |> encode()

  def encode(datetime = %DateTime{}),
    do: DateTime.to_unix(datetime)

  defp encoder(render_content), do: fn content -> encode(content, render_content) end

  # decoders

  def decode(value, opts \\ [])

  def decode(secret = %API.Secret{}, %{org_id: org_id}) do
    project_id = secret.metadata && secret.metadata.project_id_or_name
    regular_fields = ~w(id name)a
    content = decode(secret.data)

    secret.metadata
    |> Map.take(regular_fields)
    |> Map.put(:project_id, project_id)
    |> Map.put(:content, content)
    |> Map.put(:org_id, org_id)
    |> Stream.reject(&empty_field?/1)
    |> Map.new()
  end

  def decode(value, opts) when is_struct(value, MapSet),
    do: MapSet.new(value, &decode(&1, opts))

  def decode(value, opts) when is_struct(value),
    do: value |> to_plain_map() |> decode(opts)

  def decode(value, opts) when is_map(value),
    do: Enum.into(value, %{}, &decode(&1, opts))

  def decode(value, opts) when is_list(value),
    do: Enum.into(value, [], &decode(&1, opts))

  def decode({field, value}, opts),
    do: {field, decode(value, opts)}

  def decode(value, _opts) when is_binary(value), do: value
  def decode(value, _opts) when is_number(value), do: value
  def decode(value, _opts) when is_atom(value), do: value
  def decode(value, _opts) when is_boolean(value), do: value

  defp to_plain_map(protobuf_struct),
    do: protobuf_struct |> Map.drop([:__struct__, :__unknown_fields])

  defp empty_field?({_field, value}) when is_binary(value),
    do: value |> String.trim() |> String.equivalent?("")

  defp empty_field?({_field, nil}), do: true
  defp empty_field?({_field, _value}), do: false
end
