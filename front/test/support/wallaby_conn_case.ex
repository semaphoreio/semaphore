defmodule FrontWeb.WallabyCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      use Wallaby.DSL

      @moduletag :browser

      import FrontWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint FrontWeb.Endpoint
    end
  end

  setup _tags do
    Cachex.clear(:front_cache)
    Cachex.clear(:auth_cache)
    Cachex.clear!(:feature_provider_cache)
    Cacheman.clear(:front)
    Support.Stubs.init()

    Application.put_env(:wallaby, :js_errors, true)

    {:ok, session} = Wallaby.start_session(window_size: [width: 1920, height: 1080])

    {:ok, conn: Phoenix.ConnTest.build_conn(), session: session}
  end
end
