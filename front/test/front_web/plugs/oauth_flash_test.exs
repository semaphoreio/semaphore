defmodule FrontWeb.Plugs.OAuthFlashTest do
  use FrontWeb.ConnCase

  alias FrontWeb.OAuthFlashMessage
  alias FrontWeb.Plug.OAuthFlash

  # guard sends the user back to whatever redirect_path started the connect -
  # the account page, the repository chooser, a fork, or (via
  # ErrorView.connect_with/2) any page at all. Only the account page used to
  # read these params, so this plug has to work independently of the route.
  defp with_params(conn, params) do
    conn
    |> Map.put(:params, params)
    |> Plug.Test.init_test_session(%{})
    |> Phoenix.ConnTest.fetch_flash()
    |> OAuthFlash.call([])
  end

  describe "OAuthFlash plug" do
    test "maps a known error code to its message", %{conn: conn} do
      conn = with_params(conn, %{"status" => "error", "code" => "account_taken"})

      assert get_flash(conn, :alert) ==
               OAuthFlashMessage.error("account_taken")
    end

    test "falls back to the generic message for an unknown code", %{conn: conn} do
      conn = with_params(conn, %{"status" => "error", "code" => "bogus"})

      assert get_flash(conn, :alert) == OAuthFlashMessage.generic()
    end

    test "does not reflect the code back to the user", %{conn: conn} do
      attacker = "<script>alert(1)</script>"
      conn = with_params(conn, %{"status" => "error", "code" => attacker})

      flash = get_flash(conn, :alert)
      assert flash == OAuthFlashMessage.generic()
      refute flash =~ "script"
    end

    test "falls back to the generic message when no code is given", %{conn: conn} do
      # guard omits `code` on the login_not_allowed redirect
      conn = with_params(conn, %{"status" => "error"})

      assert get_flash(conn, :alert) == OAuthFlashMessage.generic()
    end

    test "sets a notice on success", %{conn: conn} do
      # the success redirect carries neither code nor provider
      conn = with_params(conn, %{"status" => "success"})

      assert get_flash(conn, :notice) == OAuthFlashMessage.success()
    end

    test "is a no-op for an ordinary request", %{conn: conn} do
      conn = with_params(conn, %{"page" => "2"})

      assert get_flash(conn, :alert) == nil
      assert get_flash(conn, :notice) == nil
    end
  end
end
