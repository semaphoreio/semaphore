defmodule Secrethub.DeploymentTargets.ActionsTest do
  use ExUnit.Case, async: true
  @moduletag capture_log: true

  alias Secrethub.DeploymentTargets.Actions
  alias Secrethub.DeploymentTargets.Secret
  alias Secrethub.Repo

  alias Support.Factories.Model, as: ModelFactory
  alias InternalApi.Secrethub, as: API

  @keys_path "priv/secret_keys_in_tests"
  @invalid_key_id "1666780781"
  @valid_key_id "1666780782"

  describe "handle functions" do
    setup [
      :repo_checkout,
      :key_vault_settings,
      :prepare_data,
      :prepare_secret,
      :prepare_params,
      :prepare_encrypted
    ]

    test "handle_list_keyset/1 when error occurs then returns error response" do
      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "Page size can't exceed 100"
                 }
               }
             } = Actions.handle_list_keyset(API.ListKeysetRequest.new(page_size: 200))
    end

    test "handle_describe/1 when error occurs then returns error response" do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "Missing request metadata"
                 }
               }
             } = Actions.handle_describe(API.DescribeRequest.new())
    end

    test "handle_create_encrypted/1 when error occurs then returns error response" do
      assert %API.CreateEncryptedResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "secret must be provided"
                 }
               }
             } = Actions.handle_create_encrypted(API.CreateEncryptedRequest.new())
    end

    test "handle_update_encrypted/1 when error occurs then returns error response" do
      assert %API.UpdateEncryptedResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "secret must be provided"
                 }
               }
             } = Actions.handle_update_encrypted(API.UpdateEncryptedRequest.new())
    end

    test "handle_destroy/1 when error occurs then returns error response" do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "deployment_target_id must be provided"
                 }
               }
             } = Actions.handle_destroy(API.DestroyRequest.new())
    end

    test "handle_describe/1 returns NOT_FOUND error response", ctx do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_describe(
                 API.DescribeRequest.new(
                   metadata: ctx.request_meta,
                   deployment_target_id: Ecto.UUID.generate()
                 )
               )
    end

    test "handle_update_encrypted/1 returns NOT_FOUND error response", ctx do
      assert %API.UpdateEncryptedResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_update_encrypted(
                 API.UpdateEncryptedRequest.new(
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | id: Ecto.UUID.generate(),
                           name: "some random name"
                       },
                       dt_config: %{
                         ctx.params.dt_config
                         | deployment_target_id: Ecto.UUID.generate()
                       }
                   },
                   encrypted_data: ctx.encrypted
                 )
               )
    end

    test "handle_destroy/1 returns NOT_FOUND error response" do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_destroy(
                 API.DestroyRequest.new(deployment_target_id: Ecto.UUID.generate())
               )
    end
  end

  describe "list_keyset/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret
    ]

    test "when page_size is above limit then raise error" do
      assert_raise GRPC.RPCError, "Page size can't exceed 100", fn ->
        Actions.list_keyset(API.ListKeysetRequest.new(page_size: 200))
      end
    end

    test "when page_size is zero then returns empty response" do
      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secrets: []
             } = Actions.list_keyset(API.ListKeysetRequest.new(page_size: 0))
    end

    test "when there is no DT secret then returns an empty list" do
      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secrets: []
             } =
               Actions.list_keyset(
                 API.ListKeysetRequest.new(
                   page_size: 10,
                   deployment_target_id: Ecto.UUID.generate()
                 )
               )
    end

    test "when page_size is within bounds then returns a list of one secret",
         ctx = %{dt_id: dt_id} do
      response =
        Actions.list_keyset(
          API.ListKeysetRequest.new(
            page_size: 1,
            deployment_target_id: ctx.dt_id
          )
        )

      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secrets: [
                 %API.Secret{
                   dt_config: %API.Secret.DTConfig{
                     deployment_target_id: ^dt_id
                   }
                 }
               ]
             } = response

      assert hd(response.secrets).data != nil
    end
  end

  describe "describe/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret
    ]

    test "when no metadata is provided then raises error", _ctx do
      assert_raise GRPC.RPCError, "Missing request metadata", fn ->
        Actions.describe(API.DescribeRequest.new())
      end
    end

    test "when metadata without organization ID is provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing argument: metadata.org_id", fn ->
        Actions.describe(API.DescribeRequest.new(metadata: %{ctx.request_meta | org_id: ""}))
      end
    end

    test "when no data is provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.describe(API.DescribeRequest.new(metadata: ctx.request_meta))
      end
    end

    test "when ID matches then returns the secret", ctx = %{dt_id: dt_id} do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 dt_config: %API.Secret.DTConfig{
                   deployment_target_id: ^dt_id
                 }
               }
             } =
               Actions.describe(
                 API.DescribeRequest.new(metadata: ctx.request_meta, id: ctx.secret.id)
               )
    end

    test "when ID does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(
          API.DescribeRequest.new(metadata: ctx.request_meta, id: Ecto.UUID.generate())
        )
      end
    end

    test "when name matches then returns the secret", ctx = %{dt_id: dt_id} do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 dt_config: %API.Secret.DTConfig{
                   deployment_target_id: ^dt_id
                 }
               }
             } =
               Actions.describe(
                 API.DescribeRequest.new(metadata: ctx.request_meta, name: ctx.secret.name)
               )
    end

    test "when name does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(API.DescribeRequest.new(metadata: ctx.request_meta, name: "random_name"))
      end
    end

    test "when DT ID matches then returns the secret", ctx = %{dt_id: dt_id} do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 dt_config: %API.Secret.DTConfig{
                   deployment_target_id: ^dt_id
                 }
               }
             } =
               Actions.describe(
                 API.DescribeRequest.new(
                   metadata: ctx.request_meta,
                   deployment_target_id: ctx.secret.dt_id
                 )
               )
    end

    test "when DT ID does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(
          API.DescribeRequest.new(
            metadata: ctx.request_meta,
            deployment_target_id: Ecto.UUID.generate()
          )
        )
      end
    end
  end

  describe "describe_many/1" do
    setup [:repo_checkout]

    test "when no data is provided then raises error" do
      assert_raise GRPC.RPCError, "DT secret API does not implement describe_many", fn ->
        Actions.describe_many(API.DescribeManyRequest.new())
      end
    end
  end

  describe "create_encrypted/1" do
    setup [
      :repo_checkout,
      :key_vault_settings,
      :prepare_data,
      :prepare_params,
      :prepare_encrypted
    ]

    test "when key_id is nil then raises error", ctx do
      assert_raise GRPC.RPCError, "Loading key failed: nil", fn ->
        Actions.create_encrypted(
          API.CreateEncryptedRequest.new(
            secret: ctx.params,
            encrypted_data: %{ctx.encrypted | key_id: nil}
          )
        )
      end
    end

    test "when key_id is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "RSA decryption error: \"#{@invalid_key_id}\"", fn ->
        Actions.create_encrypted(
          API.CreateEncryptedRequest.new(
            secret: ctx.params,
            encrypted_data: %{ctx.encrypted | key_id: @invalid_key_id}
          )
        )
      end
    end

    test "when encrypted payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "AES decryption error: \"#{@valid_key_id}\"", fn ->
        Actions.create_encrypted(
          API.CreateEncryptedRequest.new(
            secret: ctx.params,
            encrypted_data: %{ctx.encrypted | payload: Base.encode64("randompayload|")}
          )
        )
      end
    end

    test "when payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "invalid data", fn ->
        Actions.create_encrypted(
          API.CreateEncryptedRequest.new(
            secret: %{ctx.params | metadata: %{ctx.params.metadata | name: ""}},
            encrypted_data: ctx.encrypted
          )
        )
      end
    end

    test "when payload is valid then returns the secret",
         ctx = %{raw_data: raw_data, dt_id: dt_id} do
      assert %API.CreateEncryptedResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 dt_config: %API.Secret.DTConfig{deployment_target_id: ^dt_id},
                 data: nil
               },
               encrypted_data: encrypted_data = %API.EncryptedData{}
             } =
               Actions.create_encrypted(
                 API.CreateEncryptedRequest.new(
                   secret: ctx.params,
                   encrypted_data: ctx.encrypted
                 )
               )

      assert {:ok, %Secret{}} = Secrethub.DeploymentTargets.Store.find_by_target(dt_id)
      assert {:ok, ^raw_data} = Secrethub.KeyVault.decrypt(encrypted_data)
    end
  end

  describe "update_encrypted/1" do
    setup [
      :repo_checkout,
      :key_vault_settings,
      :prepare_data,
      :prepare_secret,
      :prepare_params,
      :prepare_encrypted
    ]

    test "when key_id is nil then raises error", ctx do
      assert_raise GRPC.RPCError, "Loading key failed: nil", fn ->
        Actions.update_encrypted(
          API.UpdateEncryptedRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: ctx.secret.id,
                    name: ctx.secret.name
                }
            },
            encrypted_data: %{ctx.encrypted | key_id: nil}
          )
        )
      end
    end

    test "when key_id is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "RSA decryption error: \"#{@invalid_key_id}\"", fn ->
        Actions.update_encrypted(
          API.UpdateEncryptedRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: ctx.secret.id,
                    name: ctx.secret.name
                }
            },
            encrypted_data: %{ctx.encrypted | key_id: @invalid_key_id}
          )
        )
      end
    end

    test "when encrypted payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "AES decryption error: \"#{@valid_key_id}\"", fn ->
        Actions.update_encrypted(
          API.UpdateEncryptedRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: ctx.secret.id,
                    name: ctx.secret.name
                }
            },
            encrypted_data: %{ctx.encrypted | payload: Base.encode64("randompayload|")}
          )
        )
      end
    end

    test "when payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "invalid data", fn ->
        Actions.update_encrypted(
          API.UpdateEncryptedRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: ctx.secret.id,
                    name: "TARGET!"
                }
            },
            encrypted_data: ctx.encrypted
          )
        )
      end
    end

    test "when secret does not exist then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.update_encrypted(
          API.UpdateEncryptedRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: Ecto.UUID.generate(),
                    name: "some random name"
                },
                dt_config: %{
                  ctx.params.dt_config
                  | deployment_target_id: Ecto.UUID.generate()
                }
            },
            encrypted_data: ctx.encrypted
          )
        )
      end
    end

    test "when payload is valid then returns the secret", ctx = %{dt_id: dt_id} do
      {secret_id, secret_name} = {ctx.secret.id, ctx.secret.name}

      assert %API.UpdateEncryptedResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 metadata: %API.Secret.Metadata{
                   id: ^secret_id,
                   name: ^secret_name
                 },
                 data: nil,
                 dt_config: %API.Secret.DTConfig{deployment_target_id: ^dt_id}
               },
               encrypted_data: %API.EncryptedData{}
             } =
               Actions.update_encrypted(
                 API.UpdateEncryptedRequest.new(
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | id: secret_id,
                           name: secret_name
                       }
                   },
                   encrypted_data: ctx.encrypted
                 )
               )
    end
  end

  describe "destroy/1" do
    setup [
      :repo_checkout,
      :key_vault_settings,
      :prepare_data,
      :prepare_secret,
      :prepare_params,
      :prepare_encrypted
    ]

    test "when payload is missing DT ID then returns error" do
      assert_raise GRPC.RPCError, "deployment_target_id must be provided", fn ->
        Actions.destroy(API.DestroyRequest.new())
      end
    end

    test "when DT secret is missing then returns error" do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.destroy(API.DestroyRequest.new(deployment_target_id: Ecto.UUID.generate()))
      end
    end

    test "when payload is valid then returns the secret", ctx do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               }
             } = Actions.destroy(API.DestroyRequest.new(deployment_target_id: ctx.dt_id))

      assert {:error, :not_found} = Secrethub.DeploymentTargets.Store.find_by_target(ctx.dt_id)
    end
  end

  defp repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Secrethub.Repo)
  end

  defp key_vault_settings(_context) do
    Application.put_env(:secrethub, Secrethub.KeyVault, keys_path: @keys_path)
  end

  defp prepare_data(_ctx) do
    {:ok,
     dt_id: Ecto.UUID.generate(),
     org_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now()}
  end

  defp prepare_secret(ctx) do
    name = "dt.#{ctx.dt_id}"
    content = ModelFactory.prepare_content()

    case Secrethub.Encryptor.encrypt(Poison.encode!(content), name) do
      {:ok, encrypted} ->
        {:ok,
         request_meta:
           API.RequestMeta.new(
             org_id: ctx.org_id,
             user_id: ctx.user_id
           ),
         secret:
           Repo.insert!(%Secret{
             name: "dt.#{ctx.dt_id}",
             org_id: ctx.org_id,
             dt_id: ctx.dt_id,
             created_by: ctx.user_id,
             updated_by: ctx.user_id,
             content_encrypted: encrypted,
             content: content,
             used_by: ModelFactory.prepare_checkout(),
             used_at: DateTime.truncate(ctx.now, :second)
           })}
    end
  end

  defp prepare_params(ctx) do
    {:ok,
     params:
       API.Secret.new(
         metadata:
           API.Secret.Metadata.new(
             name: "dt.#{ctx.dt_id}",
             org_id: ctx.org_id,
             level: :DEPLOYMENT_TARGET,
             created_by: ctx.user_id,
             updated_by: Ecto.UUID.generate()
           ),
         dt_config: API.Secret.DTConfig.new(deployment_target_id: ctx.dt_id)
       ),
     raw_data:
       API.Secret.Data.new(
         env_vars: [
           API.Secret.EnvVar.new(
             name: "ENV_VAR",
             value: "value"
           )
         ],
         files: [
           API.Secret.File.new(
             path: "/home/path",
             content: "content"
           )
         ]
       )}
  end

  defp prepare_encrypted(ctx) do
    alias InternalApi.Secrethub, as: API

    public_key =
      @keys_path
      |> Path.join("#{@valid_key_id}.pub.pem")
      |> ExPublicKey.load!()

    {:ok, aes256_key} = ExCrypto.generate_aes_key(:aes_256, :bytes)

    {:ok, {init_vector, payload}} =
      ExCrypto.encrypt(aes256_key, API.Secret.Data.encode(ctx.raw_data))

    {:ok, aes256_key} = ExPublicKey.encrypt_public(aes256_key, public_key)
    {:ok, init_vector} = ExPublicKey.encrypt_public(init_vector, public_key)

    {:ok,
     encrypted: %API.EncryptedData{
       key_id: @valid_key_id,
       aes256_key: aes256_key,
       init_vector: init_vector,
       payload: Base.encode64(payload)
     }}
  end
end
