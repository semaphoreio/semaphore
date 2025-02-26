defmodule Guard.GrpcServers.InstanceConfigServer do
  use GRPC.Server, service: InternalApi.InstanceConfig.InstanceConfigService.Service
  require Logger

  alias InternalApi.InstanceConfig, as: Api

  def list_configs(request, _stream) do
    Watchman.benchmark("list_configs.duration", fn ->
      request = request |> request_atom_type()
      list_configs_(request)
    end)
  end

  defp list_configs_(%Api.ListConfigsRequest{types: []}),
    do:
      raise(GRPC.RPCError,
        message: "You must specify at least one configuration type",
        status: GRPC.Status.invalid_argument()
      )

  defp list_configs_(%Api.ListConfigsRequest{types: types}) do
    case Enum.any?(types, &(&1 == :CONFIG_TYPE_UNSPECIFIED)) do
      true ->
        raise(GRPC.RPCError,
          message: "Can not list configuration for type CONFIG_TYPE_UNSPECIFIED",
          status: GRPC.Status.invalid_argument()
        )

      false ->
        configs = types |> Enum.map(&config_by_type/1)
        %Api.ListConfigsResponse{configs: configs}
    end
  end

  def modify_config(request, _stream) do
    Watchman.benchmark("modify_config.duration", fn ->
      parsed_request = request |> request_atom_type()
      response = modify_config_(parsed_request.config)

      Guard.Events.ConfigModified.publish(parsed_request.config.type)
      response
    end)
  end

  defp modify_config_(%Api.Config{state: :STATE_EMPTY, type: type}) do
    Guard.InstanceConfig.Store.delete(type)
    |> case do
      {0, _} ->
        raise(GRPC.RPCError,
          message: "Configuration not found for type #{inspect(type)}",
          status: GRPC.Status.not_found()
        )

      _ ->
        %Api.ModifyConfigResponse{}
    end
  end

  defp modify_config_(%Api.Config{type: type, fields: fields}) do
    fields =
      fields
      |> Enum.reduce(%{}, fn field, acc -> Map.put(acc, field.key, field.value) end)

    Guard.InstanceConfig.Store.get(type)
    |> case do
      nil ->
        Logger.info(
          "Creating new configuration for type #{inspect(type)} with params: #{inspect(fields)}"
        )

        changeset =
          Guard.InstanceConfig.Models.Config.changeset(%{
            name: type |> Atom.to_string(),
            config: fields
          })

        changeset
        |> Guard.InstanceConfig.Store.set()

      existing_config ->
        Logger.debug("Modify configuration for type #{inspect(type)}")

        existing_fields =
          existing_config.config
          |> Map.from_struct()
          |> Map.to_list()
          |> Enum.reduce(%{}, fn {key, value}, acc ->
            Map.put(acc, Atom.to_string(key), value)
          end)

        updated_config = Map.merge(existing_fields, fields)

        changeset =
          Guard.InstanceConfig.Models.Config.changeset(existing_config, %{
            name: type |> Atom.to_string(),
            config: updated_config
          })

        changeset
        |> Guard.InstanceConfig.Store.set()
    end
    |> case do
      {:ok, _} ->
        %Api.ModifyConfigResponse{}

      {:error, changeset} ->
        raise(GRPC.RPCError,
          message: "Error modifying configuration: #{inspect(changeset.errors)}",
          status: GRPC.Status.invalid_argument()
        )
    end
  end

  defp config_by_type(type) do
    configuration = Guard.InstanceConfig.Store.get(type)

    case configuration do
      nil ->
        build_empty_type(type)

      config ->
        config |> config_to_proto(type)
    end
  end

  defp build_empty_type(type) do
    %Api.Config{
      type: type |> Api.ConfigType.value(),
      fields: [],
      instruction_fields: instruction_fields(type),
      state: :STATE_EMPTY |> Api.State.value()
    }
  end

  defp config_to_proto(%Guard.InstanceConfig.Models.Config{} = config, type) do
    %Api.Config{
      type: type |> Api.ConfigType.value(),
      fields: fields_to_proto(config.config),
      instruction_fields: instruction_fields(type),
      state: type |> state_check(config.config) |> Api.State.value()
    }
  end

  defp fields_to_proto(config_fields),
    do: config_fields |> Map.from_struct() |> Map.to_list() |> Enum.map(&config_field_to_proto/1)

  defp instruction_fields(type),
    do: instruction_fields_(type) |> Enum.map(&config_field_to_proto/1)

  defp instruction_fields_(:CONFIG_TYPE_BITBUCKET_APP) do
    [
      redirect_urls: Guard.InstanceConfig.BitbucketApp.redirect_urls(),
      permissions: Guard.InstanceConfig.BitbucketApp.permissions()
    ]
  end

  defp instruction_fields_(:CONFIG_TYPE_GITLAB_APP) do
    [
      redirect_urls: Guard.InstanceConfig.GitlabApp.redirect_urls(),
      permissions: Guard.InstanceConfig.GitlabApp.permissions()
    ]
  end

  defp instruction_fields_(:CONFIG_TYPE_GITHUB_APP) do
    Guard.InstanceConfig.GithubApp.manifest()
    |> Map.take([:url, :callback_urls, :setup_url, :hook_attributes, :default_permissions])
    |> Map.to_list()
    |> Enum.map(fn
      {:hook_attributes, %{url: webhook_url}} ->
        {:webhook_url, webhook_url}

      {:default_permissions, permissions} ->
        {:permissions,
         permissions
         |> Enum.map_join(",", fn {scope, permission} ->
           "#{scope}:#{permission}"
         end)}

      {:callback_urls, value} ->
        {:callback_urls, value |> Enum.join(",")}

      {key, value} ->
        {key, value}
    end)
  end

  defp instruction_fields_(_), do: []

  defp config_field_to_proto({key, value}) when is_map(value) do
    config_field_to_proto(
      {key,
       value
       |> Enum.map_join(",", fn {scope, permission} ->
         "#{scope}:#{permission}"
       end)}
    )
  end

  defp config_field_to_proto({key, value}) when is_list(value) do
    config_field_to_proto({key, value |> Enum.join(",")})
  end

  defp config_field_to_proto({key, value}) do
    %Api.ConfigField{
      key: key |> Atom.to_string(),
      value: value
    }
  end

  defp request_atom_type(%Api.ListConfigsRequest{} = request) do
    %{request | types: Enum.map(request.types, &Api.ConfigType.key/1)}
  end

  defp request_atom_type(%Api.ModifyConfigRequest{} = request) do
    %{request | config: request.config |> request_atom_type()}
  end

  defp request_atom_type(%Api.Config{} = config) do
    %{
      config
      | type: config.type |> Api.ConfigType.key(),
        state: config.state |> Api.State.key()
    }
  end

  defp state_check(:CONFIG_TYPE_GITHUB_APP, config) do
    Guard.InstanceConfig.GithubApp.state_check(config)
    |> case do
      :ok ->
        :STATE_CONFIGURED

      _ ->
        :STATE_WITH_ERRORS
    end
  end

  defp state_check(:CONFIG_TYPE_INSTALLATION_DEFAULTS, _config), do: :STATE_CONFIGURED

  defp state_check(:CONFIG_TYPE_BITBUCKET_APP, config) do
    # since there is no API call to check the credentials
    # we just return :STATE_CONFIGURED if the credentials are not empty
    # return :STATE_WITH_ERRORS otherwise
    config
    |> case do
      %{client_id: client_id, client_secret: client_secret}
      when client_id != "" and client_secret != "" ->
        :STATE_CONFIGURED

      _ ->
        :STATE_WITH_ERRORS
    end
  end

  defp state_check(:CONFIG_TYPE_GITLAB_APP, config) do
    # still need to implement the check
    # for now we just return :STATE_CONFIGURED if the credentials are not empty

    config
    |> case do
      %{client_id: client_id, client_secret: client_secret}
      when client_id != "" and client_secret != "" ->
        :STATE_CONFIGURED

      _ ->
        :STATE_WITH_ERRORS
    end
  end

  defp state_check(_, _), do: :STATE_UNSPECIFIED
end
