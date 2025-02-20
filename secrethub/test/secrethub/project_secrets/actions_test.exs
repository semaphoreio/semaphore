# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Secrethub.ProjectSecrets.ActionsTest do
  use ExUnit.Case, async: true
  @moduletag capture_log: true

  alias Secrethub.ProjectSecrets.Actions
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Repo

  alias Support.Factories.Model, as: ModelFactory
  alias InternalApi.Secrethub, as: API

  describe "handle functions" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret,
      :prepare_params
    ]

    test "handle_list_keyset/1 when error occurs then returns error response", %{
      request_meta: request_meta
    } do
      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "Page size can't exceed 100"
                 }
               }
             } =
               Actions.handle_list_keyset(
                 API.ListKeysetRequest.new(metadata: request_meta, page_size: 200)
               )
    end

    test "handle_describe/1 when error occurs then returns error response", %{
      request_meta: request_meta
    } do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "Missing lookup argument"
                 }
               }
             } = Actions.handle_describe(API.DescribeRequest.new(metadata: request_meta))
    end

    test "handle_create/1 when error occurs then returns error response", %{
      request_meta: request_meta
    } do
      assert %API.CreateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "secret must be provided"
                 }
               }
             } = Actions.handle_create(API.CreateRequest.new(metadata: request_meta))
    end

    test "handle_update/1 when error occurs then returns error response", %{
      request_meta: request_meta
    } do
      assert %API.UpdateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "secret must be provided"
                 }
               }
             } = Actions.handle_update(API.UpdateRequest.new(metadata: request_meta))
    end

    test "handle_update/1 when secret id is missing then returns error response", ctx do
      assert %API.UpdateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "secret.metadata.id must be provided"
                 }
               }
             } =
               Actions.handle_update(
                 API.UpdateRequest.new(
                   metadata: ctx.request_meta,
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | id: "",
                           name: "some random name"
                       },
                       project_config: %{
                         ctx.params.project_config
                         | project_id: Ecto.UUID.generate()
                       }
                   }
                 )
               )
    end

    test "handle_destroy/1 when error occurs then returns error response", %{
      request_meta: request_meta
    } do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :FAILED_PRECONDITION,
                   message: "Missing lookup argument"
                 }
               }
             } = Actions.handle_destroy(API.DestroyRequest.new(metadata: request_meta))
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
                   name: "some random name",
                   project_id: Ecto.UUID.generate()
                 )
               )
    end

    test "handle_update/1 returns NOT_FOUND error response", ctx do
      assert %API.UpdateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_update(
                 API.UpdateRequest.new(
                   metadata: ctx.request_meta,
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | id: Ecto.UUID.generate(),
                           name: "some random name"
                       },
                       project_config: %{
                         ctx.params.project_config
                         | project_id: Ecto.UUID.generate()
                       }
                   }
                 )
               )
    end

    test "handle_destroy/1 returns NOT_FOUND error response", %{request_meta: request_meta} do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_destroy(
                 API.DestroyRequest.new(
                   id: Ecto.UUID.generate(),
                   project_id: Ecto.UUID.generate(),
                   metadata: request_meta
                 )
               )
    end

    test "handle_destroy/1 when project_id not match returns NOT_FOUND error response",
         ctx = %{request_meta: request_meta} do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :NOT_FOUND,
                   message: "secret not found"
                 }
               }
             } =
               Actions.handle_destroy(
                 API.DestroyRequest.new(
                   id: ctx.secret.id,
                   project_id: Ecto.UUID.generate(),
                   metadata: request_meta
                 )
               )
    end

    test "handle_destroy/1 returns OK error response", ctx = %{request_meta: request_meta} do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{
                   code: :OK
                 }
               }
             } =
               Actions.handle_destroy(
                 API.DestroyRequest.new(
                   id: ctx.secret.id,
                   project_id: ctx.secret.project_id,
                   metadata: request_meta
                 )
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

    test "when there is no project secrets then returns an empty list" do
      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secrets: []
             } =
               Actions.list_keyset(
                 API.ListKeysetRequest.new(
                   page_size: 10,
                   project_id: Ecto.UUID.generate()
                 )
               )
    end

    test "when page_size is within bounds then returns a list of one secret",
         ctx = %{project_id: project_id} do
      response =
        Actions.list_keyset(
          API.ListKeysetRequest.new(
            page_size: 1,
            project_id: ctx.project_id
          )
        )

      assert %API.ListKeysetResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secrets: [
                 %API.Secret{
                   project_config: %API.Secret.ProjectConfig{
                     project_id: ^project_id
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

    test "when no data is provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.describe(API.DescribeRequest.new(metadata: ctx.request_meta))
      end
    end

    test "when no project_id and name provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.describe(
          API.DescribeRequest.new(
            metadata: ctx.request_meta,
            project_id: ctx.project_id,
            name: ""
          )
        )
      end
    end

    test "when ID matches then returns the secret", ctx = %{project_id: project_id} do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 project_config: %API.Secret.ProjectConfig{
                   project_id: ^project_id
                 }
               }
             } =
               Actions.describe(
                 API.DescribeRequest.new(
                   metadata: ctx.request_meta,
                   id: ctx.secret.id,
                   project_id: ctx.secret.project_id
                 )
               )
    end

    test "when project id does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(
          API.DescribeRequest.new(
            metadata: ctx.request_meta,
            id: ctx.secret.id,
            project_id: Ecto.UUID.generate()
          )
        )
      end
    end

    test "when ID does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(
          API.DescribeRequest.new(
            metadata: ctx.request_meta,
            id: Ecto.UUID.generate(),
            project_id: ctx.secret.project_id
          )
        )
      end
    end

    test "when name does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.describe(
          API.DescribeRequest.new(
            metadata: ctx.request_meta,
            name: "random_name",
            project_id: ctx.project_id
          )
        )
      end
    end

    test "when project_id and name matches then returns the secret",
         ctx = %{project_id: project_id} do
      assert %API.DescribeResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 project_config: %API.Secret.ProjectConfig{
                   project_id: ^project_id
                 }
               }
             } =
               Actions.describe(
                 API.DescribeRequest.new(
                   metadata: ctx.request_meta,
                   project_id: ctx.secret.project_id,
                   name: ctx.secret.name
                 )
               )
    end
  end

  describe "describe_many/1" do
    setup [:repo_checkout]

    test "when no data is provided then raises error" do
      assert_raise GRPC.RPCError,
                   "Project level secret API does not implement describe_many",
                   fn ->
                     Actions.describe_many(API.DescribeManyRequest.new())
                   end
    end
  end

  describe "create/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_params
    ]

    test "when payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "content: can't be blank", fn ->
        Actions.create(
          API.CreateRequest.new(
            secret: %{ctx.params | metadata: %{ctx.params.metadata | name: ""}}
          )
        )
      end
    end

    test "when payload is valid then returns the secret",
         ctx = %{raw_data: raw_data, project_id: project_id} do
      assert %API.CreateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 project_config: %API.Secret.ProjectConfig{project_id: ^project_id},
                 data: ^raw_data
               }
             } = Actions.create(API.CreateRequest.new(secret: %{ctx.params | data: raw_data}))

      assert {:ok, %Secret{}} =
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.params.metadata.name
               )
    end
  end

  describe "update/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret,
      :prepare_params
    ]

    test "when payload is invalid then raises error", ctx = %{raw_data: raw_data} do
      assert_raise GRPC.RPCError,
                   "description: should be at most 255 character(s)",
                   fn ->
                     Actions.update(
                       API.UpdateRequest.new(
                         metadata: ctx.request_meta,
                         secret: %{
                           ctx.params
                           | metadata: %{
                               ctx.params.metadata
                               | id: ctx.secret.id,
                                 description: String.duplicate("a", 256)
                             },
                             data: raw_data
                         }
                       )
                     )
                   end
    end

    test "when secret does not exist then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.update(
          API.UpdateRequest.new(
            metadata: ctx.request_meta,
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: Ecto.UUID.generate(),
                    name: "some random name"
                },
                project_config: %{
                  ctx.params.project_config
                  | project_id: Ecto.UUID.generate()
                }
            }
          )
        )
      end
    end

    test "when payload is valid then returns the secret", ctx = %{project_id: project_id} do
      {secret_id, secret_name, data} = {ctx.secret.id, ctx.secret.name, ctx.raw_data}

      assert %API.UpdateResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               },
               secret: %API.Secret{
                 metadata: %API.Secret.Metadata{
                   id: ^secret_id,
                   name: ^secret_name
                 },
                 data: ^data,
                 project_config: %API.Secret.ProjectConfig{project_id: ^project_id}
               }
             } =
               Actions.update(
                 API.UpdateRequest.new(
                   metadata: ctx.request_meta,
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | id: secret_id,
                           name: secret_name
                       },
                       data: ctx.raw_data
                   }
                 )
               )
    end
  end

  describe "destroy/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret,
      :prepare_params
    ]

    test "when payload is missing project_id and name and id then returns error", %{
      request_meta: request_meta
    } do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.destroy(API.DestroyRequest.new(metadata: request_meta))
      end
    end

    test "when secret is missing then returns error", %{request_meta: request_meta} do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.destroy(
          API.DestroyRequest.new(
            metadata: request_meta,
            project_id: Ecto.UUID.generate(),
            name: "some name"
          )
        )
      end
    end

    test "when payload is valid then returns the secret", ctx do
      assert %API.DestroyResponse{
               metadata: %API.ResponseMeta{
                 status: %API.ResponseMeta.Status{code: :OK}
               }
             } =
               Actions.destroy(
                 API.DestroyRequest.new(
                   metadata: ctx.request_meta,
                   project_id: ctx.project_id,
                   name: ctx.secret.name
                 )
               )

      assert {:error, :not_found} =
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.secret.name
               )
    end
  end

  defp repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Secrethub.Repo)
  end

  defp prepare_data(_ctx) do
    {:ok,
     project_id: Ecto.UUID.generate(),
     org_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now()}
  end

  defp prepare_secret(ctx) do
    name = "dt.#{ctx.project_id}"
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
             name: name,
             org_id: ctx.org_id,
             project_id: ctx.project_id,
             created_by: ctx.user_id,
             updated_by: ctx.user_id,
             content: ModelFactory.prepare_content(),
             content_encrypted: encrypted,
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
             name: "dt.#{ctx.project_id}",
             org_id: ctx.org_id,
             level: :PROJECT,
             created_by: ctx.user_id,
             updated_by: Ecto.UUID.generate()
           ),
         project_config: API.Secret.ProjectConfig.new(project_id: ctx.project_id)
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
end
