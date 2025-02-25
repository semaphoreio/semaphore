defmodule Front.GithubApp do
  @cache_key "github_app"

  def app_url do
    case Application.get_env(:front, :github_app_url) do
      nil -> get("html_url")
      "" -> get("html_url")
      url -> url
    end
  end

  def get(field) do
    with {:ok, gh_app} when not is_nil(gh_app) <- Cachex.get(:front_cache, @cache_key),
         field when not is_nil(field) <- gh_app.fields[field] do
      field
    else
      _ -> get_from_api(field)
    end
  end

  def get_from_api(field) do
    Front.Models.InstanceConfig.list_integrations(:CONFIG_TYPE_GITHUB_APP)
    |> case do
      {:ok, integration} ->
        Cachex.put(:front_cache, @cache_key, integration)
        integration.fields[field]

      {:error, _} ->
        ""
    end
  end
end
