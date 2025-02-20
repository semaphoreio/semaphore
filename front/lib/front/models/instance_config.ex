defmodule Front.Models.InstanceConfig do
  alias InternalApi.InstanceConfig.{
    ListConfigsRequest,
    ModifyConfigRequest,
    Config,
    ConfigField,
    ConfigType,
    State
  }

  alias InternalApi.InstanceConfig.InstanceConfigService

  @secret_fields ~w(client_id client_secret pem webhook_secret)

  def list_integrations(types, opts \\ [secrets: false])

  def list_integrations(types, opts) when is_list(types) do
    request = %ListConfigsRequest{
      types: Enum.map(types, &InternalApi.InstanceConfig.ConfigType.value/1)
    }

    InstanceConfigService.Stub.list_configs(channel(), request)
    |> case do
      {:ok, response} -> {:ok, response.configs |> Enum.map(parse_config(opts[:secrets]))}
      {:error, error} -> {:error, error}
    end
  end

  def list_integrations(type, opts) do
    list_integrations([type], opts)
    |> case do
      {:ok, [integration]} -> {:ok, integration}
      {:ok, []} -> {:error, "Integration not found"}
      {:error, error} -> {:error, error}
    end
  end

  def modify_integration(type, status, fields) do
    request = %ModifyConfigRequest{
      config: %Config{
        type: type |> ConfigType.value(),
        state: status |> State.value(),
        fields: Enum.map(fields, fn {k, v} -> %ConfigField{key: k, value: v} end)
      }
    }

    InstanceConfigService.Stub.modify_config(channel(), request)
    |> case do
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp parse_config(with_secrets) do
    fn config ->
      %{
        type: config.type |> ConfigType.key(),
        state: config.state |> State.key(),
        fields: flatten_fields(config.fields, with_secrets),
        instruction_fields: flatten_fields(config.instruction_fields, true)
      }
    end
  end

  defp flatten_fields(fields, with_secrets) do
    Enum.reduce(fields, %{}, fn field, acc ->
      case with_secrets do
        true ->
          Map.put(acc, field.key, field.value)

        false ->
          case Enum.member?(@secret_fields, field.key) do
            true -> acc
            false -> Map.put(acc, field.key, field.value)
          end
      end
    end)
  end

  defp channel do
    {:ok, ch} = GRPC.Stub.connect(Application.fetch_env!(:front, :instance_config_grpc_endpoint))
    ch
  end
end
