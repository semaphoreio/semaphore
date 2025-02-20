defmodule Secrethub.ProjectSecrets.PublicAPIActionsTest do
  use ExUnit.Case, async: true
  @moduletag capture_log: true

  alias Secrethub.ProjectSecrets.PublicAPIActions, as: Actions
  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.Repo

  alias Support.Factories.Model, as: ModelFactory
  alias Semaphore.ProjectSecrets.V1, as: API

  use Support.PrepareFunctions, API

  describe "list_secrets/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret
    ]

    test "when page_size is above limit then raise error" do
      assert_raise GRPC.RPCError, "Page size can't exceed 100", fn ->
        Actions.list_secrets(API.ListSecretsRequest.new(page_size: 200), nil)
      end
    end

    test "when there is no project secrets then returns an empty list", ctx do
      assert %API.ListSecretsResponse{
               secrets: []
             } =
               Actions.list_secrets(
                 API.ListSecretsRequest.new(
                   page_size: 10,
                   project_id_or_name: Ecto.UUID.generate()
                 ),
                 get_meta(ctx)
               )
    end

    test "when page_size is within bounds then returns a list of one secret",
         ctx = %{project_id: project_id} do
      assert %API.ListSecretsResponse{
               secrets: [
                 %API.Secret{
                   metadata: %API.Secret.Metadata{
                     project_id_or_name: ^project_id
                   }
                 }
               ]
             } =
               Actions.list_secrets(
                 API.ListSecretsRequest.new(
                   page_size: 1,
                   project_id_or_name: ctx.project_id
                 ),
                 get_meta(ctx)
               )
    end

    test "when render_content false then env_vars and files contents are empty",
         ctx = %{project_id: project_id} do
      assert %API.ListSecretsResponse{
               secrets: [
                 %API.Secret{
                   metadata: %API.Secret.Metadata{
                     project_id_or_name: ^project_id,
                     content_included: false
                   },
                   data: %API.Secret.Data{
                     env_vars: [
                       %Semaphore.ProjectSecrets.V1.Secret.EnvVar{name: "VAR1", value: ""},
                       %Semaphore.ProjectSecrets.V1.Secret.EnvVar{name: "VAR2", value: ""}
                     ],
                     files: [
                       %Semaphore.ProjectSecrets.V1.Secret.File{content: "", path: "/home/path1"},
                       %Semaphore.ProjectSecrets.V1.Secret.File{content: "", path: "/home/path2"}
                     ]
                   }
                 }
               ]
             } =
               Actions.list_secrets(
                 API.ListSecretsRequest.new(
                   page_size: 1,
                   project_id_or_name: ctx.project_id
                 ),
                 get_meta(ctx, false)
               )
    end
  end

  describe "get_secret/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret
    ]

    test "when no data is provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.get_secret(API.GetSecretRequest.new(), get_meta(ctx))
      end
    end

    test "when no secret data is provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.get_secret(
          API.GetSecretRequest.new(project_id_or_name: ctx.project_id),
          get_meta(ctx)
        )
      end
    end

    test "when no project_id and name provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.get_secret(
          API.GetSecretRequest.new(
            project_id_or_name: ctx.project_id,
            secret_id_or_name: ""
          ),
          get_meta(ctx)
        )
      end
    end

    test "when no project name or id provided then raises error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.get_secret(
          API.GetSecretRequest.new(
            project_id_or_name: "",
            secret_id_or_name: ctx.secret.name
          ),
          get_meta(ctx)
        )
      end
    end

    test "when ID matches then returns the secret",
         ctx = %{project_id: project_id, secret: %{name: name}} do
      assert %API.Secret{
               metadata: %API.Secret.Metadata{
                 name: ^name,
                 project_id_or_name: ^project_id
               }
             } =
               Actions.get_secret(
                 API.GetSecretRequest.new(
                   secret_id_or_name: ctx.secret.id,
                   project_id_or_name: ctx.project_id
                 ),
                 get_meta(ctx)
               )
    end

    test "when ID does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.get_secret(
          API.GetSecretRequest.new(
            secret_id_or_name: Ecto.UUID.generate(),
            project_id_or_name: ctx.project_id
          ),
          get_meta(ctx)
        )
      end
    end

    test "when name does not match then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.get_secret(
          API.GetSecretRequest.new(
            secret_id_or_name: "random_name",
            project_id_or_name: ctx.project_id
          ),
          get_meta(ctx)
        )
      end
    end

    test "when project_id and name matches then returns the secret",
         ctx = %{project_id: project_id, secret: %{name: name}} do
      assert %API.Secret{
               metadata: %API.Secret.Metadata{
                 name: ^name,
                 project_id_or_name: ^project_id
               }
             } =
               Actions.get_secret(
                 API.GetSecretRequest.new(
                   project_id_or_name: ctx.secret.project_id,
                   secret_id_or_name: ctx.secret.name
                 ),
                 get_meta(ctx)
               )
    end

    test "when secret content should not be renderd -> returns secret without contents",
         ctx = %{project_id: project_id, secret: %{name: name}} do
      assert %API.Secret{
               metadata: %API.Secret.Metadata{
                 name: ^name,
                 project_id_or_name: ^project_id,
                 content_included: false
               },
               data: %API.Secret.Data{
                 env_vars: [
                   %API.Secret.EnvVar{name: "VAR1", value: ""},
                   %API.Secret.EnvVar{name: "VAR2", value: ""}
                 ],
                 files: [
                   %API.Secret.File{content: "", path: "/home/path1"},
                   %API.Secret.File{content: "", path: "/home/path2"}
                 ]
               }
             } =
               Actions.get_secret(
                 API.GetSecretRequest.new(
                   secret_id_or_name: ctx.secret.id,
                   project_id_or_name: ctx.project_id
                 ),
                 get_meta(ctx, false)
               )
    end
  end

  describe "create/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_params
    ]

    test "when payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, ~r/can't be blank/, fn ->
        Actions.create_secret(
          API.Secret.new(%{ctx.params | metadata: %{ctx.params.metadata | name: ""}}),
          get_meta(ctx)
        )
      end
    end

    test "when payload is valid then returns the secret",
         ctx = %{raw_data: raw_data, project_id: project_id} do
      assert %API.Secret{
               metadata: %API.Secret.Metadata{project_id_or_name: ^project_id},
               data: ^raw_data
             } =
               Actions.create_secret(
                 API.Secret.new(%{ctx.params | data: raw_data}),
                 get_meta(ctx)
               )

      assert {:ok, %Secret{}} =
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.params.metadata.name
               )
    end

    test "when payload is valid, but should not render contents then returns the secret without contents",
         ctx = %{raw_data: raw_data, project_id: project_id} do
      return_data = %{
        raw_data
        | env_vars:
            Enum.map(raw_data.env_vars, fn e -> %API.Secret.EnvVar{name: e.name, value: ""} end),
          files: Enum.map(raw_data.files, fn f -> %API.Secret.File{path: f.path, content: ""} end)
      }

      assert %API.Secret{
               metadata: %API.Secret.Metadata{project_id_or_name: ^project_id},
               data: ^return_data
             } =
               Actions.create_secret(
                 API.Secret.new(%{ctx.params | data: raw_data}),
                 get_meta(ctx, false)
               )

      assert {:ok, %Secret{}} =
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.params.metadata.name
               )
    end
  end

  describe "update_secret/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret,
      :prepare_params
    ]

    test "when payload is invalid then raises error", ctx do
      assert_raise GRPC.RPCError, "secret.secret_id_or_name must be provided", fn ->
        Actions.update_secret(
          API.UpdateSecretRequest.new(
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: ctx.secret.id,
                    name: "SECRET!"
                }
            }
          ),
          get_meta(ctx)
        )
      end
    end

    test "when secret does not exist then raises error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.update_secret(
          API.UpdateSecretRequest.new(
            secret_id_or_name: Ecto.UUID.generate(),
            project_id_or_name: ctx.project_id,
            secret: %{
              ctx.params
              | metadata: %{
                  ctx.params.metadata
                  | id: Ecto.UUID.generate(),
                    name: "some random name"
                }
            }
          ),
          get_meta(ctx)
        )
      end
    end

    test "when payload is valid then returns the secret", ctx = %{project_id: project_id} do
      {secret_id, secret_name, data} = {ctx.secret.id, ctx.secret.name, ctx.raw_data}

      assert %API.Secret{
               metadata: %API.Secret.Metadata{
                 id: ^secret_id,
                 name: ^secret_name,
                 project_id_or_name: ^project_id
               },
               data: ^data
             } =
               Actions.update_secret(
                 API.UpdateSecretRequest.new(
                   secret_id_or_name: secret_id,
                   project_id_or_name: project_id,
                   secret: %{
                     ctx.params
                     | metadata: %{
                         ctx.params.metadata
                         | name: secret_name
                       },
                       data: ctx.raw_data
                   }
                 ),
                 get_meta(ctx)
               )
    end
  end

  describe "delete_secret/1" do
    setup [
      :repo_checkout,
      :prepare_data,
      :prepare_secret,
      :prepare_params
    ]

    test "when payload is missing project_id and name and id then returns error", ctx do
      assert_raise GRPC.RPCError, "Missing lookup argument", fn ->
        Actions.delete_secret(API.DeleteSecretRequest.new(), get_meta(ctx))
      end
    end

    test "when secret is missing then returns error", ctx do
      assert_raise GRPC.RPCError, "secret not found", fn ->
        Actions.delete_secret(
          API.DeleteSecretRequest.new(
            project_id_or_name: Ecto.UUID.generate(),
            secret_id_or_name: "some name"
          ),
          get_meta(ctx)
        )
      end
    end

    test "when payload is valid then returns the secret", ctx do
      assert %API.Empty{} =
               Actions.delete_secret(
                 API.DeleteSecretRequest.new(
                   project_id_or_name: ctx.project_id,
                   secret_id_or_name: ctx.secret.name
                 ),
                 get_meta(ctx)
               )

      assert {:error, :not_found} =
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.secret.name
               )
    end
  end

  defp get_meta(ctx, render_content \\ true),
    do: Map.take(ctx, ~w(org_id user_id)a) |> Map.put(:render_content, render_content)
end
