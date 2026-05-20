defmodule PublicAPI.Plugs.FeatureFlagTest do
  use ExUnit.Case
  use Plug.Test

  alias Support.Stubs.Feature

  @test_feature "public_api_v1"
  @org_id UUID.uuid4()

  defmodule ViewOrgSettings do
    use Plug.Builder

    plug(PublicAPI.Plugs.RequestAssigns)

    plug(PublicAPI.Plugs.FeatureFlag,
      feature: "public_api_v1"
    )

    plug(:settings)

    def settings(conn, _opts) do
      Plug.Conn.send_resp(conn, 200, "response")
    end
  end

  defmodule TestRouter do
    use Plug.Router

    plug(Plug.Logger, log: :debug)
    plug(PublicAPI.Plugs.RequestAssigns)
    plug(PublicAPI.Plugs.FeatureFlag, feature: "public_api_v1", except: ~w(/ /ping))

    plug(:match)
    plug(:dispatch)

    for path <- ~w(/ /ping /workflows /pipelines) do
      get path do
        send_resp(conn, 200, "pong")
      end
    end
  end

  describe "handler plug integration" do
    setup [:invalidate_cache]

    test "should return 200 if feature flag is enabled" do
      Feature.enable_feature(@org_id, @test_feature)

      conn =
        request(:get, "/")
        |> ViewOrgSettings.call([])

      assert conn.status == 200
    end

    test "should return 404 if feature flag is disabled" do
      Feature.disable_feature(@org_id, @test_feature)

      conn =
        request(:get, "/")
        |> ViewOrgSettings.call([])

      assert conn.status == 404
    end
  end

  describe "router integration" do
    setup [:invalidate_cache]

    test "if feature flagged route and feature enabled => respond 200" do
      Feature.enable_feature(@org_id, @test_feature)

      conn =
        request(:get, "/workflows")
        |> TestRouter.call([])

      assert conn.status == 200
    end

    test "if feature flagged route and feature disabled => respond 404" do
      Feature.disable_feature(@org_id, @test_feature)

      conn =
        request(:get, "/workflows")
        |> TestRouter.call([])

      assert conn.status == 404
    end

    test "if route in exept list and feature disabled => respond 200" do
      Feature.disable_feature(@org_id, @test_feature)

      conn =
        request(:get, "/")
        |> TestRouter.call([])

      assert conn.status == 200
    end
  end

  defp request(method, path),
    do:
      conn(method, path)
      |> put_req_header("x-semaphore-org-id", @org_id)

  defp invalidate_cache(_ctx) do
    cache_name = :feature_provider_cache
    FeatureProvider.CachexCache.clear(name: cache_name)

    :ok
  end
end
