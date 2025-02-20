defmodule Secrethub.ProjectSecrets.StoreTest do
  use ExUnit.Case, async: true

  alias Secrethub.ProjectSecrets.Secret
  alias Secrethub.ProjectSecrets.Store
  alias Secrethub.Model
  alias Secrethub.Repo

  alias Support.Factories.Model, as: ModelFactory

  setup_all [:prepare_data, :prepare_features]

  describe "list_by_ids/1" do
    setup [:repo_checkout, :prepare_secret]

    test "when ids are empty list then return empty list" do
      assert [] = Store.list_by_ids([])
    end

    test "when secret is missing then return empty list" do
      assert [] = Store.list_by_ids([Ecto.UUID.generate()])
    end

    test "when secret exists then return it", ctx do
      assert [secret] = Store.list_by_ids([ctx.secret.id])
      assert ^secret = ctx.secret
    end
  end

  describe "list_by_names/2" do
    setup [:repo_checkout, :prepare_secret]

    test "when names are empty list then return empty list", ctx do
      assert [] = Store.list_by_names(ctx.org_id, ctx.secret.project_id, [])
    end

    test "when name is missing then return empty list", ctx do
      assert [] = Store.list_by_names(ctx.org_id, ctx.secret.project_id, [Ecto.UUID.generate()])
    end

    test "when organization ID is nil then return empty list", ctx do
      assert [] = Store.list_by_names(nil, ctx.secret.project_id, [ctx.secret.name])
    end

    test "when organization ID is empty string then return empty list", ctx do
      assert [] = Store.list_by_names("", ctx.secret.project_id, [ctx.secret.name])
    end

    test "when secret is missing then return empty list", ctx do
      assert [] = Store.list_by_names(ctx.org_id, ctx.secret.project_id, ["randomname"])
    end

    test "when secret exists then return it", ctx do
      assert [secret] = Store.list_by_names(ctx.org_id, ctx.secret.project_id, [ctx.secret.name])
      assert ^secret = ctx.secret
    end
  end

  describe "find_by_name/2" do
    setup [:repo_checkout, :prepare_secret]

    test "when name is nil then return error with :not_found", ctx do
      assert {:error, :not_found} = Store.find_by_name(ctx.org_id, ctx.secret.project_id, nil)
    end

    test "when name is empty string then return error with :not_found", ctx do
      assert {:error, :not_found} = Store.find_by_name(ctx.org_id, ctx.secret.project_id, "")
    end

    test "when organization ID is nil then return error with :not_found", ctx do
      assert {:error, :not_found} =
               Store.find_by_name(nil, ctx.secret.project_id, ctx.secret.name)
    end

    test "when organization ID is empty string then return error with :not_found", ctx do
      assert {:error, :not_found} = Store.find_by_name("", ctx.secret.project_id, ctx.secret.name)
    end

    test "when secret is missing then return error with :not_found", ctx do
      assert {:error, :not_found} =
               Store.find_by_name(ctx.org_id, ctx.secret.project_id, "random_name")
    end

    test "when secret exists then return it", ctx do
      assert {:ok, secret} =
               Store.find_by_name(ctx.org_id, ctx.secret.project_id, ctx.secret.name)

      assert ^secret = ctx.secret
    end
  end

  describe "list_by_project_id/2" do
    setup [:repo_checkout, :prepare_secret]

    test "when project_id is nil then return error with :not_found" do
      assert {:error, :not_found} = Store.list_by_project_id(nil, false)
    end

    test "when project_id is empty string then return error with :not_found" do
      assert {:error, :not_found} = Store.list_by_project_id("", false)
    end

    test "when secret exists then return it", ctx do
      assert {:ok, secret} = Store.list_by_project_id(ctx.secret.project_id, false)
      assert ^secret = [ctx.secret]
    end
  end

  describe "create/1" do
    setup [:repo_checkout, :prepare_secret, :prepare_params]

    test "when params are invalid then return error with changeset", ctx do
      assert {:error, %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", _}]}} =
               Store.create(%{ctx.params | name: ""})
    end

    test "when params are valid but secret already exists then return error", ctx do
      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [name: {"name must be unique in project", _}]
              }} =
               Store.create(%{
                 ctx.params
                 | name: ctx.secret.name,
                   project_id: ctx.secret.project_id
               })
    end

    test "when params are valid then return ok with secret", ctx do
      assert {:ok, secret} = Store.create(ctx.params)
      assert {:ok, from_db} = Repo.get(Secret, secret.id) |> Secrethub.Encryptor.decrypt_secret()
      assert ^secret = from_db
    end
  end

  describe "update/1" do
    setup [:repo_checkout, :prepare_secret, :prepare_extra_secret, :prepare_params]

    test "when params are invalid then return error with changeset", ctx do
      assert {:error, %Ecto.Changeset{valid?: false, errors: [name: {"can't be blank", _}]}} =
               Store.update(ctx.secret, %{ctx.params | name: ""})
    end

    test "when params are valid but secret already exists then return error", ctx do
      assert {:error,
              %Ecto.Changeset{
                valid?: false,
                errors: [name: {"name must be unique in project", _}]
              }} =
               Store.create(%{
                 ctx.params
                 | name: ctx.extra_secret.name,
                   project_id: ctx.extra_secret.project_id
               })
    end

    test "when params are valid then return ok with secret", ctx do
      assert {:ok, secret} = Store.update(ctx.secret, ctx.params)

      assert {:ok,
              %Secret{
                content: %Model.Content{
                  env_vars: [
                    %Model.EnvVar{name: "VAR1", value: "value1"},
                    %Model.EnvVar{name: "VAR2", value: "value2"}
                  ],
                  files: [
                    %Model.File{path: "/home/path1", content: "content1"},
                    %Model.File{path: "/home/path2", content: "content2"}
                  ]
                }
              }} = Secrethub.Encryptor.decrypt_secret(Repo.get(Secret, secret.id))
    end
  end

  describe "delete/1" do
    setup [:repo_checkout, :prepare_secret]

    test "when entity exists then return ok with secret", ctx do
      assert {:ok, secret} = Store.delete(ctx.secret)
      assert is_nil(Repo.get(Secret, secret.id))
    end
  end

  describe "checkout_many/2" do
    setup [:repo_checkout, :prepare_secret, :prepare_extra_secret]

    test "when params are valid then return ok with secrets without changing updated_at", ctx do
      assert [secret] = Store.checkout_many([ctx.secret], %{job_id: "job_id"})

      checkouted_secret = Repo.get(Secret, secret.id)

      assert %Secret{
               content: nil
             } = checkouted_secret

      assert ctx.secret.updated_at == checkouted_secret.updated_at
    end
  end

  defp repo_checkout(_context) do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  defp prepare_data(_ctx) do
    {:ok,
     org_id: Ecto.UUID.generate(),
     project_id: Ecto.UUID.generate(),
     project_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now()}
  end

  defp prepare_params(ctx) do
    {:ok,
     params: %{
       name: "Staging",
       project_id: Ecto.UUID.generate(),
       org_id: ctx.org_id,
       created_by: ctx.user_id,
       updated_by: ctx.user_id,
       content: ModelFactory.prepare_content_params(),
       used_by: ModelFactory.prepare_checkout_params(),
       used_at: DateTime.truncate(ctx.now, :second)
     }}
  end

  defp prepare_secret(ctx) do
    name = "Production"
    content = %Model.Content{}

    case Secrethub.Encryptor.encrypt(Poison.encode!(content), name) do
      {:ok, encrypted} ->
        {:ok,
         secret:
           Repo.insert!(%Secret{
             name: name,
             project_id: ctx.project_id,
             org_id: ctx.org_id,
             created_by: ctx.user_id,
             updated_by: ctx.user_id,
             content: content,
             content_encrypted: encrypted
           })}
    end
  end

  defp prepare_features(_ctx) do
    Support.FakeServices.enable_features([])
  end

  defp prepare_extra_secret(ctx) do
    {:ok,
     extra_secret:
       Repo.insert!(%Secret{
         name: "Canary",
         project_id: Ecto.UUID.generate(),
         org_id: ctx.org_id,
         created_by: ctx.user_id,
         updated_by: ctx.user_id,
         content: %Model.Content{}
       })}
  end
end
