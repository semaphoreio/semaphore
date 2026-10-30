defmodule FrontWeb.ProjectForkControllerTest do
  use FrontWeb.ConnCase

  import Mock

  alias Front.Models
  alias FrontWeb.OAuthFlashMessage
  alias FrontWeb.ProjectForkController

  # after_auth/2 is where a failed connect lands when the fork flow started it.
  # The provider is still unsupported at that point - that is what failing
  # means - so this is the branch that runs, and it is the branch that used to
  # overwrite whatever FrontWeb.Plug.OAuthFlash had already put in the flash.
  defp after_auth(conn) do
    with_mocks([
      {Models.User, [], [find: fn _ -> %{id: "u1"} end]},
      {Models.Forkable, [],
       [
         find: fn _ -> %{name: "repo"} end,
         supported_by_user?: fn _, _ -> false end
       ]},
      {FeatureProvider, [], [feature_enabled?: fn _, _ -> false end]}
    ]) do
      ProjectForkController.after_auth(conn, %{
        "repository_name" => "repo",
        "provider" => "github"
      })
    end
  end

  defp conn_with_flash(conn, flash) do
    conn
    |> Plug.Conn.assign(:user_id, "u1")
    |> Plug.Conn.assign(:organization_id, "org1")
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.ConnTest.fetch_flash()
    |> then(fn c ->
      case flash do
        nil -> c
        message -> Phoenix.Controller.put_flash(c, :alert, message)
      end
    end)
  end

  describe "after_auth/2 when the provider is still not connected" do
    test "keeps the reason OAuthFlash already put in the flash", %{conn: conn} do
      specific = OAuthFlashMessage.error("account_taken")

      conn = conn |> conn_with_flash(specific) |> after_auth()

      assert get_flash(conn, :alert) == specific
      refute get_flash(conn, :alert) == "Failed to connect with Repository."
    end

    test "still falls back to the generic alert when nothing set one", %{conn: conn} do
      conn = conn |> conn_with_flash(nil) |> after_auth()

      assert get_flash(conn, :alert) == "Failed to connect with Repository."
    end
  end
end
