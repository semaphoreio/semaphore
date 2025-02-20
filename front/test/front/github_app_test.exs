defmodule Front.GithubAppTest do
  use ExUnit.Case

  @moduletag :comunity_edition

  test "when environment contains github app, use it" do
    old = Application.get_env(:front, :github_app_url)
    Application.put_env(:front, :github_app_url, "https://application.env")

    assert "https://application.env" == Front.GithubApp.app_url()

    Application.put_env(:front, :github_app_url, old)
  end

  test "when environment does not contain github app, fetch from instance config service" do
    old = Application.get_env(:front, :github_app_url)
    Application.delete_env(:front, :github_app_url)
    Support.Stubs.InstanceConfig.setup_github_app()

    assert "https://github.com/instance_config" == Front.GithubApp.app_url()

    Application.put_env(:front, :github_app_url, old)
  end
end
