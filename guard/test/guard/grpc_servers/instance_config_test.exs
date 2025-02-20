defmodule Guard.GrpcServers.InstanceConfigServerTest do
  use Guard.RepoCase, async: false

  alias InternalApi.InstanceConfig
  alias InternalApi.InstanceConfig.InstanceConfigService.Stub
  alias Guard.InstanceConfig.Store

  @not_found GRPC.Status.not_found()
  @invalid_argument GRPC.Status.invalid_argument()

  setup do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    Guard.Mocks.GithubAppApi.github_app_api()
    Guard.InstanceConfigRepo.delete_all(Guard.InstanceConfig.Models.Config)

    {:ok, %{grpc_channel: channel}}
  end

  describe "list_configs" do
    test "when config type unspecified raise error", %{grpc_channel: channel} do
      request = %InstanceConfig.ListConfigsRequest{
        types: [InstanceConfig.ConfigType.value(:CONFIG_TYPE_UNSPECIFIED)]
      }

      {:error, message} = channel |> Stub.list_configs(request)

      assert %GRPC.RPCError{
               status: @invalid_argument,
               message: "Can not list configuration for type CONFIG_TYPE_UNSPECIFIED"
             } = message
    end

    test "when config type is ok return the configuration for github app", %{
      grpc_channel: channel
    } do
      setup_github_app_integration()

      setup = Store.get(:CONFIG_TYPE_GITHUB_APP)

      request = %InstanceConfig.ListConfigsRequest{
        types: [InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP)]
      }

      assert {:ok, response} = channel |> Stub.list_configs(request)

      assert %InstanceConfig.ListConfigsResponse{
               configs: [
                 %InstanceConfig.Config{
                   type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
                   fields: gh_app_config_fields(setup.config.pem),
                   instruction_fields: gh_app_instruction_fields(),
                   state: InstanceConfig.State.value(:STATE_CONFIGURED)
                 }
               ]
             } == response
    end

    test "when config type is ok return the configuration for installation defaults", %{
      grpc_channel: channel
    } do
      setup_installation_defaults_integration()

      setup = Store.get(:CONFIG_TYPE_INSTALLATION_DEFAULTS)

      request = %InstanceConfig.ListConfigsRequest{
        types: [InstanceConfig.ConfigType.value(:CONFIG_TYPE_INSTALLATION_DEFAULTS)]
      }

      assert {:ok, response} = channel |> Stub.list_configs(request)

      assert %InstanceConfig.ListConfigsResponse{
               configs: [
                 %InstanceConfig.Config{
                   type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_INSTALLATION_DEFAULTS),
                   fields:
                     installation_defaults_config_fields(
                       installation_id: setup.config.installation_id,
                       kube_version: setup.config.kube_version,
                       organization_id: setup.config.organization_id,
                       telemetry_endpoint: setup.config.telemetry_endpoint
                     ),
                   instruction_fields: [],
                   state: InstanceConfig.State.value(:STATE_CONFIGURED)
                 }
               ]
             } == response
    end

    test "when config type is ok but configuration status check fails", %{grpc_channel: channel} do
      {:ok, setup} = setup_github_app_integration()

      Tesla.Mock.mock_global(fn
        %{method: :get, url: "https://api.github.com/app"} ->
          resp = %Tesla.Env{
            status: 401,
            body: %{
              "message" => "Bad credentials",
              "documentation_url" => "https://developer.github.com/v3"
            }
          }

          {:ok, resp}
      end)

      Store.get(:CONFIG_TYPE_GITHUB_APP)

      request = %InstanceConfig.ListConfigsRequest{
        types: [InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP)]
      }

      assert {:ok, response} = channel |> Stub.list_configs(request)

      assert %InstanceConfig.ListConfigsResponse{
               configs: [
                 %InstanceConfig.Config{
                   type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
                   fields: gh_app_config_fields(setup.config.pem),
                   instruction_fields: gh_app_instruction_fields(),
                   state: InstanceConfig.State.value(:STATE_WITH_ERRORS)
                 }
               ]
             } == response
    end
  end

  describe "modify_config" do
    test "fails when no config in db and not all fields are present", %{grpc_channel: channel} do
      request = %InstanceConfig.ModifyConfigRequest{
        config: %InstanceConfig.Config{
          type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
          fields: [
            %InstanceConfig.ConfigField{
              key: "id",
              value: "3213"
            }
          ],
          state: InstanceConfig.State.value(:STATE_UNSPECIFIED)
        }
      }

      assert {:error, response} = channel |> Stub.modify_config(request)

      assert %GRPC.RPCError{
               status: @invalid_argument,
               message: message
             } = response

      assert message =~ "can't be blank"
    end

    test "successfully sets github app integration", %{grpc_channel: channel} do
      fields =
        %{
          app_id: "3213",
          slug: "test-gh-app",
          client_secret: "client_secret",
          client_id: "client_id",
          pem: "pem",
          webhook_secret: "webhook_secret",
          html_url: "https://github.com"
        }
        |> Map.to_list()
        |> Enum.map(fn {k, v} ->
          %InstanceConfig.ConfigField{key: k |> Atom.to_string(), value: v}
        end)

      request = %InstanceConfig.ModifyConfigRequest{
        config: %InstanceConfig.Config{
          type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
          fields: fields,
          state: InstanceConfig.State.value(:STATE_UNSPECIFIED)
        }
      }

      assert {:ok, response} = channel |> Stub.modify_config(request)

      assert %InstanceConfig.ModifyConfigResponse{} == response

      integration = Store.get(:CONFIG_TYPE_GITHUB_APP)

      assert %{
               app_id: "3213",
               slug: "test-gh-app",
               client_secret: "client_secret",
               client_id: "client_id",
               pem: "pem",
               webhook_secret: "webhook_secret",
               html_url: "https://github.com"
             } = integration.config
    end

    test "successfully sets installation defaults integration", %{grpc_channel: channel} do
      fields =
        %{
          installation_id: Ecto.UUID.generate(),
          kube_version: "v1.31.4+k3s1",
          organization_id: Ecto.UUID.generate(),
          telemetry_endpoint: "http://localhost:4000/telemetry"
        }
        |> Map.to_list()
        |> Enum.map(fn {k, v} ->
          %InstanceConfig.ConfigField{key: k |> Atom.to_string(), value: v}
        end)

      request = %InstanceConfig.ModifyConfigRequest{
        config: %InstanceConfig.Config{
          type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_INSTALLATION_DEFAULTS),
          fields: fields,
          state: InstanceConfig.State.value(:STATE_UNSPECIFIED)
        }
      }

      assert {:ok, response} = channel |> Stub.modify_config(request)

      assert %InstanceConfig.ModifyConfigResponse{} == response

      integration = Store.get(:CONFIG_TYPE_INSTALLATION_DEFAULTS)

      assert %{
               installation_id: _,
               kube_version: "v1.31.4+k3s1",
               organization_id: _,
               telemetry_endpoint: "http://localhost:4000/telemetry"
             } = integration.config
    end

    test "unknown config fields for a type ignored", %{grpc_channel: channel} do
      fields =
        %{
          app_id: "3213",
          slug: "test-gh-app",
          client_secret: "client_secret",
          client_id: "client_id",
          pem: "pem",
          webhook_secret: "webhook_secret",
          html_url: "https://github.com",
          unknown_field: "unknown"
        }
        |> Map.to_list()
        |> Enum.map(fn {k, v} ->
          %InstanceConfig.ConfigField{key: k |> Atom.to_string(), value: v}
        end)

      request = %InstanceConfig.ModifyConfigRequest{
        config: %InstanceConfig.Config{
          type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
          fields: fields,
          state: InstanceConfig.State.value(:STATE_UNSPECIFIED)
        }
      }

      assert {:ok, response} = channel |> Stub.modify_config(request)
      assert %InstanceConfig.ModifyConfigResponse{} == response

      integration = Store.get(:CONFIG_TYPE_GITHUB_APP)

      assert %{
               app_id: "3213",
               slug: "test-gh-app",
               client_id: "client_id",
               client_secret: "client_secret",
               pem: "pem",
               html_url: "https://github.com",
               webhook_secret: "webhook_secret"
             } = integration.config
    end

    test "when configuration exists, update only provided fields", %{grpc_channel: channel} do
      {:ok, integration} = setup_github_app_integration()

      fields =
        %{
          client_secret: "client_secret_updated",
          client_id: "client_id_updated"
        }
        |> Map.to_list()
        |> Enum.map(fn {k, v} ->
          %InstanceConfig.ConfigField{key: k |> Atom.to_string(), value: v}
        end)

      request = %InstanceConfig.ModifyConfigRequest{
        config: %InstanceConfig.Config{
          type: InstanceConfig.ConfigType.value(:CONFIG_TYPE_GITHUB_APP),
          fields: fields,
          state: InstanceConfig.State.value(:STATE_UNSPECIFIED)
        }
      }

      assert {:ok, response} = channel |> Stub.modify_config(request)

      assert %InstanceConfig.ModifyConfigResponse{} == response

      integration_updated = Store.get(:CONFIG_TYPE_GITHUB_APP)

      assert integration_updated.config == %{
               integration.config
               | client_secret: "client_secret_updated",
                 client_id: "client_id_updated"
             }
    end
  end

  describe "modify_config -> destroy" do
    test "when integration is not set raise error", %{grpc_channel: channel} do
      request = delete_request(:CONFIG_TYPE_GITHUB_APP)
      {:error, message} = channel |> Stub.modify_config(request)

      assert %GRPC.RPCError{
               status: @not_found
             } = message
    end

    test "when integration is set, remove it", %{grpc_channel: channel} do
      setup_github_app_integration()

      request = delete_request(:CONFIG_TYPE_GITHUB_APP)

      {:ok, message} = channel |> Stub.modify_config(request)

      assert %InstanceConfig.ModifyConfigResponse{} = message
    end
  end

  defp setup_github_app_integration do
    private_key = JOSE.JWK.generate_key({:rsa, 1024})
    {_, pem_private_key} = JOSE.JWK.to_pem(private_key)

    Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
      name: :CONFIG_TYPE_GITHUB_APP |> Atom.to_string(),
      config: %{
        app_id: "3213",
        slug: "slug",
        name: "name",
        client_id: "client_id",
        client_secret: "client_secret",
        pem: pem_private_key,
        html_url: "https://github.com",
        webhook_secret: "webhook_secret"
      }
    })
    |> Store.set()
  end

  defp setup_installation_defaults_integration(params \\ []) do
    config = %{
      "installation_id" => Keyword.get(params, :installation_id, Ecto.UUID.generate()),
      "kube_version" => Keyword.get(params, :kube_version, "v1.31.4+k3s1"),
      "organization_id" => Keyword.get(params, :organization_id, Ecto.UUID.generate()),
      "telemetry_endpoint" =>
        Keyword.get(params, :telemetry_endpoint, "http://localhost:4000/telemetry")
    }

    Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
      name: :CONFIG_TYPE_INSTALLATION_DEFAULTS |> Atom.to_string(),
      config: config
    })
    |> Store.set()
  end

  defp delete_request(type) do
    %InstanceConfig.ModifyConfigRequest{
      config: %InstanceConfig.Config{
        type: InstanceConfig.ConfigType.value(type),
        state: InstanceConfig.State.value(:STATE_EMPTY)
      }
    }
  end

  defp gh_app_config_fields(pem) do
    [
      %InstanceConfig.ConfigField{key: "app_id", value: "3213"},
      %InstanceConfig.ConfigField{
        key: "client_id",
        value: "client_id"
      },
      %InstanceConfig.ConfigField{
        key: "client_secret",
        value: "client_secret"
      },
      %InstanceConfig.ConfigField{
        key: "html_url",
        value: "https://github.com"
      },
      %InstanceConfig.ConfigField{key: "name", value: "name"},
      %InstanceConfig.ConfigField{key: "pem", value: pem},
      %InstanceConfig.ConfigField{key: "slug", value: "slug"},
      %InstanceConfig.ConfigField{
        key: "webhook_secret",
        value: "webhook_secret"
      }
    ]
  end

  defp gh_app_instruction_fields do
    [
      %InternalApi.InstanceConfig.ConfigField{
        key: "callback_urls",
        value:
          "https://id.localhost/auth/github/callback,https://id.localhost/oauth/github/callback"
      },
      %InternalApi.InstanceConfig.ConfigField{
        key: "permissions",
        value:
          "administration:write,checks:write,contents:write,emails:read,issues:read,members:read,metadata:read,organization_hooks:write,pull_requests:read,repository_hooks:write,statuses:write"
      },
      %InternalApi.InstanceConfig.ConfigField{
        key: "webhook_url",
        value: "https://hooks.localhost/github"
      },
      %InternalApi.InstanceConfig.ConfigField{
        key: "setup_url",
        value: "https://me.localhost/github_app_installation"
      },
      %InternalApi.InstanceConfig.ConfigField{key: "url", value: "https://id.localhost"}
    ]
  end

  defp installation_defaults_config_fields(params) do
    [
      %InstanceConfig.ConfigField{
        key: "installation_id",
        value: Keyword.get(params, :installation_id, Ecto.UUID.generate())
      },
      %InstanceConfig.ConfigField{
        key: "kube_version",
        value: Keyword.get(params, :kube_version, "v1.31.4+k3s1")
      },
      %InstanceConfig.ConfigField{
        key: "organization_id",
        value: Keyword.get(params, :organization_id, Ecto.UUID.generate())
      },
      %InstanceConfig.ConfigField{
        key: "telemetry_endpoint",
        value: Keyword.get(params, :telemetry_endpoint, "http://localhost:4000/telemetry")
      }
    ]
  end
end
