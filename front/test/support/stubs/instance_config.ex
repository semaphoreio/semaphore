defmodule Support.Stubs.InstanceConfig do
  alias Support.Stubs.DB
  require Logger

  def init do
    DB.add_table(:config, [:name, :config])

    __MODULE__.Grpc.init()
  end

  def setup_github_app do
    {:ok, key} = ExPublicKey.generate_key()
    {:ok, pem_key} = ExPublicKey.pem_encode(key)

    DB.insert(:config, %{
      name: "CONFIG_TYPE_GITHUB_APP",
      config: [
        %InternalApi.InstanceConfig.ConfigField{key: "app_id", value: "123"},
        %InternalApi.InstanceConfig.ConfigField{key: "slug", value: "slug"},
        %InternalApi.InstanceConfig.ConfigField{key: "name", value: "name"},
        %InternalApi.InstanceConfig.ConfigField{
          key: "html_url",
          value: "https://github.com/instance_config"
        },
        %InternalApi.InstanceConfig.ConfigField{key: "client_id", value: "client_id"},
        %InternalApi.InstanceConfig.ConfigField{key: "client_secret", value: "client_secret"},
        %InternalApi.InstanceConfig.ConfigField{key: "pem", value: pem_key},
        %InternalApi.InstanceConfig.ConfigField{key: "webhook_secret", value: "webhook_secret"}
      ]
    })
  end

  def setup_gitlab_app do
    DB.insert(:config, %{
      name: "CONFIG_TYPE_GITLAB_APP",
      config: [
        %InternalApi.InstanceConfig.ConfigField{key: "client_id", value: "client_id"},
        %InternalApi.InstanceConfig.ConfigField{key: "client_secret", value: "client_secret"}
      ]
    })
  end

  def setup_bitbucket_app do
    DB.insert(:config, %{
      name: "CONFIG_TYPE_BITBUCKET_APP",
      config: [
        %InternalApi.InstanceConfig.ConfigField{key: "client_id", value: "client_id"},
        %InternalApi.InstanceConfig.ConfigField{key: "client_secret", value: "client_secret"}
      ]
    })
  end

  def setup_installation_defaults_config do
    DB.insert(:config, %{
      name: "CONFIG_TYPE_INSTALLATION_DEFAULTS",
      config: [
        %InternalApi.InstanceConfig.ConfigField{
          key: "organization_id",
          value: "2a5a4d1c-38b2-4528-9028-0e6e1bbc2c52"
        },
        %InternalApi.InstanceConfig.ConfigField{
          key: "installation_id",
          value: "6a5a4d1c-38b2-4528-9028-0e6e1bbc2c52"
        },
        %InternalApi.InstanceConfig.ConfigField{
          key: "kube_version",
          value: "v1.31.4+k3s1"
        },
        %InternalApi.InstanceConfig.ConfigField{
          key: "telemetry_endpoint",
          value: "https://telemetry.semaphoreci.com/ingest"
        }
      ]
    })
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(InstanceConfigMock, :list_configs, &__MODULE__.list_configs/2)
      GrpcMock.stub(InstanceConfigMock, :modify_config, &__MODULE__.modify_config/2)
    end

    def list_configs(req, _) do
      configs =
        Enum.map(req.types, fn type ->
          {type |> InternalApi.InstanceConfig.ConfigType.key(),
           DB.find_by(
             :config,
             :name,
             type |> InternalApi.InstanceConfig.ConfigType.key() |> Atom.to_string()
           )}
        end)

      %InternalApi.InstanceConfig.ListConfigsResponse{
        configs:
          Enum.map(configs, fn
            {type, nil} ->
              %InternalApi.InstanceConfig.Config{
                type: type |> InternalApi.InstanceConfig.ConfigType.value(),
                fields: [],
                instruction_fields: build_instruction_fields(type),
                state: InternalApi.InstanceConfig.State.value(:STATE_EMPTY)
              }

            {type, config} ->
              %InternalApi.InstanceConfig.Config{
                type: type |> InternalApi.InstanceConfig.ConfigType.value(),
                fields: config.config,
                instruction_fields: build_instruction_fields(type),
                state: InternalApi.InstanceConfig.State.value(:STATE_CONFIGURED)
              }
          end)
      }
    end

    defp build_instruction_fields(type),
      do:
        build_instruction_fields_(type)
        |> Enum.map(fn {key, val} ->
          %InternalApi.InstanceConfig.ConfigField{key: key, value: val}
        end)

    defp build_instruction_fields_(:CONFIG_TYPE_BITBUCKET_APP) do
      permissions =
        %{
          "Accounts" => "read",
          "Issues" => "read",
          "Workspace membership" => "read",
          "Projects" => "read",
          "Webhooks" => "read and write",
          "Repositories" => "admin",
          "Pull requests" => "write"
        }
        |> Enum.map_join(",", fn {scope, permission} ->
          "#{scope}:#{permission}"
        end)

      base_domain = System.get_env("BASE_DOMAIN") || "localhost"

      [
        {"permissions", permissions},
        {"redirect_urls",
         "https://id.#{base_domain}/oauth/gitlab/callback,https://id.#{base_domain}/auth/gitlab/callback"}
      ]
    end

    defp build_instruction_fields_(:CONFIG_TYPE_GITLAB_APP) do
      permissions =
        %{
          "api" => "true",
          "read_api" => "true",
          "read_user" => "true",
          "read_repository" => "true",
          "write_repository" => "true",
          "openid" => "true"
        }
        |> Enum.map_join(",", fn {scope, permission} ->
          "#{scope}:#{permission}"
        end)

      base_domain = System.get_env("BASE_DOMAIN") || "localhost"

      [
        {"permissions", permissions},
        {"redirect_urls", "https://id.#{base_domain}/oauth/gitlab/callback"}
      ]
    end

    defp build_instruction_fields_(:CONFIG_TYPE_GITHUB_APP) do
      base_domain = System.get_env("BASE_DOMAIN") || "localhost"

      permissions =
        %{
          "administration" => "write",
          "checks" => "write",
          "contents" => "write",
          "emails" => "read",
          "issues" => "read",
          "members" => "read",
          "metadata" => "read",
          "organization_hooks" => "write",
          "pull_requests" => "read",
          "repository_hooks" => "write",
          "statuses" => "write"
        }
        |> Enum.map_join(",", fn {scope, permission} ->
          "#{scope}:#{permission}"
        end)

      [
        {"callback_urls",
         "https://id.#{base_domain}/auth/github/callback,https://id.#{base_domain}/oauth/github/callback"},
        {"permissions", permissions},
        {"webhook_url", "https://hooks.#{base_domain}/github"},
        {"setup_url", "https://me.#{base_domain}/github_app_installation"},
        {"url", "https://id.#{base_domain}"}
      ]
    end

    defp build_instruction_fields_(_) do
      []
    end

    def modify_config(req, _) do
      type = req.config.type |> InternalApi.InstanceConfig.ConfigType.key() |> Atom.to_string()
      state = req.config.state |> InternalApi.InstanceConfig.State.key()

      case state do
        :STATE_EMPTY ->
          Logger.debug("Destroying config: #{type}")
          destroy_config_(type)

        _ ->
          DB.find_by(:config, :name, type)
          |> case do
            nil ->
              create_config_(type, req)

            old ->
              Logger.debug("updating config: #{type}, #{inspect(req)}")
              update_config_(type, old, req)
          end
      end
    end

    defp create_config_(type, req) do
      DB.insert(:config, %{name: type, config: req.config.fields})
      %InternalApi.InstanceConfig.ModifyConfigResponse{}
    end

    defp update_config_(type, old, req) do
      config = merge_configs(old.config, req.config.fields)
      Logger.debug("merged configs: #{inspect(config)}")
      DB.update(:config, %{name: type, config: config}, :name)
      %InternalApi.InstanceConfig.ModifyConfigResponse{}
    end

    defp destroy_config_(type) do
      DB.delete(:config, fn e -> e.name == type end)
      %InternalApi.InstanceConfig.ModifyConfigResponse{}
    end

    defp merge_configs(old, new) do
      existing_fields =
        old
        |> Enum.reduce(%{}, fn %{key: key, value: value}, acc ->
          Map.put(acc, key, value)
        end)

      Enum.reduce(new, existing_fields, fn %{key: key, value: value}, acc ->
        Map.put(acc, key, value)
      end)
      |> Enum.map(fn {key, value} ->
        %InternalApi.InstanceConfig.ConfigField{key: key, value: value}
      end)
    end
  end
end
