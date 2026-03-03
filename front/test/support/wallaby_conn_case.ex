defmodule FrontWeb.WallabyCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Plug.Conn
      import Phoenix.ConnTest
      use Wallaby.DSL
      require Wallaby.Browser
      import Wallaby.Browser, except: [assert_text: 2, assert_has: 2, refute_has: 2]
      import Support.Browser.Assertions
      import FrontWeb.WallabyCase, only: [browser_test: 2, browser_test: 3]

      @moduletag :browser

      import FrontWeb.Router.Helpers

      # The default endpoint for testing
      @endpoint FrontWeb.Endpoint
    end
  end

  defmacro browser_test(message, context \\ quote(do: _), contents) do
    context = Macro.escape(context)
    contents = Macro.escape(contents, unquote: true)

    quote bind_quoted: [context: context, contents: contents, message: message] do
      name = ExUnit.Case.register_test(__MODULE__, __ENV__.file, __ENV__.line, :test, message, [])

      def unquote(name)(unquote(context)) do
        unquote(contents)
      rescue
        exception ->
          if Wallaby.screenshot_on_failure?() do
            Wallaby.Feature.Utils.take_screenshots_for_sessions(
              self(),
              to_string(unquote(message))
            )
          end

          reraise(exception, __STACKTRACE__)
      end
    end
  end

  setup _tags do
    Cachex.clear(:front_cache)
    Cachex.clear(:auth_cache)
    Cachex.clear!(:feature_provider_cache)
    Cacheman.clear(:front)
    Support.Stubs.init()

    Application.put_env(:wallaby, :js_errors, true)

    {:ok, session} = Wallaby.start_session()

    on_exit(fn ->
      Wallaby.end_session(session)
    end)

    {:ok, conn: Phoenix.ConnTest.build_conn(), session: session}
  end
end
