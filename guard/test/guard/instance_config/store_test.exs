defmodule Guard.InstanceConfig.StoreTest do
  use Guard.RepoCase, async: true
  alias Guard.InstanceConfig.Store

  describe "get" do
    test "when no integration is set" do
      Guard.InstanceConfigRepo.delete_all(Guard.InstanceConfig.Models.Config)
      assert nil == Store.get(:CONFIG_TYPE_GITHUB_APP)
    end

    test "when integration is set" do
      assert {:ok, _} =
               Store.set(
                 Guard.InstanceConfig.Models.Config.changeset(%{
                   name: "CONFIG_TYPE_GITHUB_APP",
                   config: %{
                     app_id: "3213",
                     slug: "slug",
                     name: "name",
                     client_id: "client_id",
                     client_secret: "client_secret",
                     pem: "pem",
                     html_url: "https://github.com",
                     webhook_secret: "webhook_secret"
                   }
                 })
               )

      assert %{
               name: "CONFIG_TYPE_GITHUB_APP",
               config: %Guard.InstanceConfig.Models.GithubApp{
                 app_id: "3213",
                 slug: "slug",
                 name: "name",
                 client_id: "client_id",
                 client_secret: "client_secret",
                 pem: "pem",
                 html_url: "https://github.com",
                 webhook_secret: "webhook_secret"
               }
             } = Store.get(:CONFIG_TYPE_GITHUB_APP)
    end
  end

  describe "set" do
    test "when no config is provided" do
      assert {:error, changeset} =
               Store.set(
                 Guard.InstanceConfig.Models.Config.changeset(%{
                   name: "CONFIG_TYPE_GITHUB_APP",
                   config: %{}
                 })
               )

      assert false == changeset.valid?
    end

    test "when data is provided" do
      assert {:ok, _} =
               Store.set(
                 Guard.InstanceConfig.Models.Config.changeset(%{
                   name: "CONFIG_TYPE_GITHUB_APP",
                   config: %{
                     app_id: "3213",
                     slug: "slug",
                     name: "name",
                     client_id: "client_id",
                     client_secret: "client_secret",
                     pem: "pem",
                     html_url: "https://github.com",
                     webhook_secret: "webhook_secret"
                   }
                 })
               )
    end
  end
end
