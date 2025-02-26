defmodule Guard.GitProviderCredentialsTest do
  use Guard.RepoCase, async: false
  alias Guard.InstanceConfig.Store

  setup do
    Application.put_env(:guard, :include_instance_config, true)
    Guard.Mocks.GithubAppApi.github_app_api()
    Guard.InstanceConfigRepo.delete_all(Guard.InstanceConfig.Models.Config)
    Cachex.clear(:config_cache)

    :ok
  end

  describe "get/1" do
    test "should retrieve valid credentials from each provider when instance config is configured" do
      setup_github_app_integration()
      setup_gitlab_app_integration()
      setup_bitbucket_app_integration()

      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:github)
      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:gitlab)
      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:bitbucket)
    end

    test "should return error when provider is not configured" do
      assert {:error, :not_found} == Guard.GitProviderCredentials.get(:github)
      assert {:error, :not_found} == Guard.GitProviderCredentials.get(:gitlab)
      assert {:error, :not_found} == Guard.GitProviderCredentials.get(:bitbucket)
    end

    test "should refetch from instance config when cache is wrong" do
      setup_github_app_integration()
      setup_gitlab_app_integration()
      setup_bitbucket_app_integration()

      Cachex.put(:config_cache, "github_credentials", %{client_id: nil, client_secret: nil})
      Cachex.put(:config_cache, "gitlab_credentials", %{client_id: nil, client_secret: nil})
      Cachex.put(:config_cache, "bitbucket_credentials", %{client_id: nil, client_secret: nil})

      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:github)
      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:gitlab)
      assert {:ok, {"client_id", "client_secret"}} == Guard.GitProviderCredentials.get(:bitbucket)
    end

    test "should get credentials from cache if it contains valid credentials" do
      Cachex.put(:config_cache, "github_credentials", %{
        client_id: "cached_client_id",
        client_secret: "cached_secret"
      })

      Cachex.put(:config_cache, "gitlab_credentials", %{
        client_id: "cached_client_id",
        client_secret: "cached_secret"
      })

      Cachex.put(:config_cache, "bitbucket_credentials", %{
        client_id: "cached_client_id",
        client_secret: "cached_secret"
      })

      assert {:ok, {"cached_client_id", "cached_secret"}} ==
               Guard.GitProviderCredentials.get(:github)

      assert {:ok, {"cached_client_id", "cached_secret"}} ==
               Guard.GitProviderCredentials.get(:gitlab)

      assert {:ok, {"cached_client_id", "cached_secret"}} ==
               Guard.GitProviderCredentials.get(:bitbucket)
    end
  end

  defp setup_github_app_integration() do
    private_key = JOSE.JWK.generate_key({:rsa, 1024})
    {_, pem_private_key} = JOSE.JWK.to_pem(private_key)

    Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
      name: :CONFIG_TYPE_GITHUB_APP |> Atom.to_string(),
      config: %{
        app_id: "11111111111111111111111",
        slug: "slug",
        name: "name",
        client_id: client_id,
        client_secret: client_secret,
        pem: pem_private_key,
        html_url: "https://github.com",
        webhook_secret: "webhook_secret"
      }
    })
    |> Store.set()
  end

  defp setup_gitlab_app_integration() do
    Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
      name: :CONFIG_TYPE_GITLAB_APP |> Atom.to_string(),
      config: %{
        client_id: client_id,
        client_secret: client_secret
      }
    })
    |> Store.set()
  end

  defp setup_bitbucket_app_integration() do
    Guard.InstanceConfig.Models.Config.changeset(%Guard.InstanceConfig.Models.Config{}, %{
      name: :CONFIG_TYPE_BITBUCKET_APP |> Atom.to_string(),
      config: %{
        client_id: client_id,
        client_secret: client_secret
      }
    })
    |> Store.set()
  end
end
