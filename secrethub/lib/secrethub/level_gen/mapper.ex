defmodule Secrethub.LevelGen.Mapper do
  alias Secrethub.LevelGen.Util

  defmacro __using__(opts) do
    model = Util.get_mandatory_field(opts, :model)
    level = Util.get_mandatory_field(opts, :level)
    level_config = Util.get_mandatory_field(opts, :level_config)
    decode_regular_fields = Util.get_mandatory_field(opts, :regular_fields)

    encode_description_code =
      if level_config == :project_config do
        quote do
          secret.description
        end
      else
        quote do
          ""
        end
      end

    level_config_code =
      if level_config == :project_config do
        quote do
          [project_config: API.Secret.ProjectConfig.new(project_id: secret.project_id)]
        end
      else
        quote do
          [dt_config: API.Secret.DTConfig.new(deployment_target_id: secret.dt_id)]
        end
      end

    decode_id_code =
      if level_config == :project_config do
        quote do
          conf_id = secret.project_config && secret.project_config.project_id
        end
      else
        quote do
          conf_id = secret.dt_config && secret.dt_config.deployment_target_id
        end
      end

    decode_id_field =
      if level_config == :project_config do
        quote do
          :project_id
        end
      else
        quote do
          :dt_id
        end
      end

    quote do
      alias InternalApi.Secrethub, as: API
      alias unquote(model)
      alias Secrethub.Model

      # encoders
      def encode(secrets) when is_list(secrets), do: Enum.map(secrets, &encode/1)

      def encode(secret = %Secret{}) do
        API.Secret.new(
          [
            metadata:
              API.Secret.Metadata.new(
                id: secret.id,
                name: secret.name,
                description: unquote(encode_description_code),
                org_id: secret.org_id,
                level: unquote(level),
                created_by: secret.created_by,
                updated_by: secret.updated_by,
                last_checkout: secret.used_by && encode(secret.used_by),
                created_at: secret.inserted_at && encode(secret.inserted_at),
                updated_at: secret.updated_at && encode(secret.updated_at),
                checkout_at: secret.used_at && encode(secret.used_at)
              ),
            data: secret.content && encode(secret.content)
          ] ++
            unquote(level_config_code)
        )
      end

      def encode(checkout = %Model.Checkout{}) do
        checkout |> Map.from_struct() |> API.CheckoutMetadata.new()
      end

      def encode(content = %Model.Content{}) do
        API.Secret.Data.new(
          env_vars: Enum.into(content.env_vars, [], &encode/1),
          files: Enum.into(content.files, [], &encode/1)
        )
      end

      def encode(env_var = %Model.EnvVar{}),
        do: API.Secret.EnvVar.new(name: env_var.name, value: env_var.value)

      def encode(file = %Model.File{}),
        do: API.Secret.File.new(path: file.path, content: file.content)

      def encode(naive_datetime = %NaiveDateTime{}),
        do: naive_datetime |> DateTime.from_naive!("Etc/UTC") |> encode()

      def encode(datetime = %DateTime{}),
        do: Google.Protobuf.Timestamp.new(seconds: DateTime.to_unix(datetime))

      # decoders

      def decode(value, opts \\ [])

      def decode(secret = %API.Secret{}, _opts) do
        unquote(decode_id_code)

        regular_fields = unquote(decode_regular_fields)
        content = decode(secret.data)

        secret.metadata
        |> Map.take(regular_fields)
        |> Map.put(unquote(decode_id_field), conf_id)
        |> Map.put(:content, content)
        |> Stream.reject(&empty_field?/1)
        |> Map.new()
      end

      def decode(ts = %Google.Protobuf.Timestamp{}, _opts) do
        DateTime.from_unix!(ts.seconds * 1_000_000_000 + ts.nanos, :millisecond)
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
  end
end
