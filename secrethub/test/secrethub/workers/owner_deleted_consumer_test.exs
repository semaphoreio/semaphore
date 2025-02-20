defmodule Secrethub.Workers.OwnerDeletedConsumer.Test do
  use Secrethub.DataCase

  import Mock

  alias Secrethub.Workers.OwnerDeletedConsumer
  alias Support.Factories.Model, as: ModelFactory
  alias Secrethub.OpenIDConnect.JWTConfiguration

  describe ".deleted_project" do
    setup [:prepare_data, :insert_secrets]

    test "destroys the secret", ctx do
      message =
        InternalApi.Projecthub.ProjectDeleted.new(project_id: ctx.project_id)
        |> InternalApi.Projecthub.ProjectDeleted.encode()

      OwnerDeletedConsumer.deleted_project(message)

      assert {:error, :not_found} ==
               Secrethub.ProjectSecrets.Store.find_by_name(
                 ctx.org_id,
                 ctx.project_id,
                 ctx.project_secret.name
               )
    end

    test "logs errors and re-raises", ctx do
      message =
        InternalApi.Projecthub.ProjectDeleted.new(project_id: ctx.project_id)
        |> InternalApi.Projecthub.ProjectDeleted.encode()

      with_mocks([
        {Secrethub.ProjectSecrets.Store, [],
         [destroy_many: fn _m -> raise RuntimeError, message: "Something failed" end]},
        {Watchman, [], [benchmark: fn _, fun -> fun.() end, increment: fn _m -> :ok end]}
      ]) do
        assert_raise RuntimeError, "Something failed", fn ->
          OwnerDeletedConsumer.deleted_project(message)
        end

        assert_called(Watchman.increment(:_))
      end
    end
  end

  describe ".deleted_organization" do
    setup [:prepare_data, :insert_secrets]

    test "destroy all the secrets", ctx do
      message =
        InternalApi.Organization.OrganizationDeleted.new(org_id: ctx.org_id)
        |> InternalApi.Organization.OrganizationDeleted.encode()

      OwnerDeletedConsumer.deleted_organization(message)

      assert {:error, :not_found} ==
               Secrethub.Secret.find_by_name(ctx.org_id, ctx.org_secret.name)
    end
  end

  describe "JWT configuration deletion" do
    setup [:prepare_data]

    test "deletes project JWT configuration when project is deleted", ctx do
      # Create project JWT config
      {:ok, _} =
        JWTConfiguration.create_or_update_project_config(ctx.org_id, ctx.project_id, [
          %{"name" => "sub", "is_active" => true}
        ])

      message =
        InternalApi.Projecthub.ProjectDeleted.new(project_id: ctx.project_id, org_id: ctx.org_id)
        |> InternalApi.Projecthub.ProjectDeleted.encode()

      OwnerDeletedConsumer.deleted_project(message)

      assert {:error, :not_found} ==
               JWTConfiguration.delete_project_config(ctx.org_id, ctx.project_id)
    end

    test "deletes organization JWT configuration when organization is deleted", ctx do
      # Create org JWT config
      {:ok, _} =
        JWTConfiguration.create_or_update_org_config(ctx.org_id, [
          %{"name" => "sub", "is_active" => true}
        ])

      # Create project JWT config to ensure it's also deleted
      {:ok, _} =
        JWTConfiguration.create_or_update_project_config(ctx.org_id, ctx.project_id, [
          %{"name" => "sub", "is_active" => true}
        ])

      message =
        InternalApi.Organization.OrganizationDeleted.new(org_id: ctx.org_id)
        |> InternalApi.Organization.OrganizationDeleted.encode()

      OwnerDeletedConsumer.deleted_organization(message)

      # Both org and project configs should be deleted
      assert {:error, :not_found} == JWTConfiguration.delete_org_config(ctx.org_id)

      assert {:error, :not_found} ==
               JWTConfiguration.delete_project_config(ctx.org_id, ctx.project_id)
    end
  end

  defp prepare_data(_ctx) do
    {:ok,
     org_id: Ecto.UUID.generate(),
     project_id: Ecto.UUID.generate(),
     user_id: Ecto.UUID.generate(),
     now: DateTime.utc_now()}
  end

  def insert_secrets(ctx) do
    {
      :ok,
      project_secret:
        Secrethub.Repo.insert!(%Secrethub.ProjectSecrets.Secret{
          name: "project.#{Ecto.UUID.generate()}",
          org_id: ctx.org_id,
          project_id: ctx.project_id,
          created_by: ctx.user_id,
          updated_by: ctx.user_id,
          content: ModelFactory.prepare_content(),
          used_by: ModelFactory.prepare_checkout(),
          used_at: DateTime.truncate(ctx.now, :second)
        }),
      org_secret:
        Secrethub.Repo.insert!(%Secrethub.Secret{
          name: "org.#{Ecto.UUID.generate()}",
          org_id: ctx.org_id,
          created_by: ctx.user_id,
          updated_by: ctx.user_id,
          content: ModelFactory.prepare_content(),
          used_by: ModelFactory.prepare_checkout_params(),
          used_at: DateTime.truncate(ctx.now, :second)
        })
    }
  end
end
