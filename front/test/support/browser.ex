defmodule Support.Browser do
  use Wallaby.DSL
  require Wallaby.Browser

  alias Wallaby.{Browser, Query, StaleReferenceError}

  @stale_retry_attempts 5
  @stale_retry_delay 100

  def fetch_js_value(session, script) do
    session
    |> execute_script(script, fn value ->
      send(self(), {:ok, value})
    end)

    receive do
      {:ok, value} -> {:ok, value}
    after
      3_000 ->
        raise "Value can't be fetched"
    end
  end

  @doc """
  Returns {:ok, path} on success.
  Raises error if the value can't be extracted.
  """
  def get_current_path(session) do
    fetch_js_value(session, "return window.location.pathname")
  end

  @doc """
  Disables the confirm dialogs in browsers.
  """
  def disable_confirm_dialog(session) do
    session |> execute_script("window.confirm = function(){return true;}")
  end

  @doc """
  Disables the onunload handler
  """
  def disable_onbeforeunload_dialog(session) do
    session |> execute_script("window.onbeforeunload = null;")
  end

  @doc """
  Like `assert_has/2`, but retries automatically if the DOM was replaced.
  """
  def assert_stable(session, query) do
    retry_on_stale(fn -> Browser.assert_has(session, query) end)
    session
  end

  @doc """
  Like `assert_text/2`, but retries automatically if the DOM was replaced.
  """
  def assert_stable_text(session, text) do
    retry_on_stale(fn -> Browser.assert_text(session, text) end)
    session
  end

  @doc """
  Waits for the global flash banner rendered in `_action_notification.html.eex`.
  """
  def assert_flash_notice(session, text) do
    assert_stable(session, Query.css("#changes-notification p", text: text))
  end

  def retry_on_stale(fun, attempts \\ @stale_retry_attempts)
  def retry_on_stale(fun, 0), do: fun.()

  def retry_on_stale(fun, attempts) do
    fun.()
  rescue
    _ in StaleReferenceError ->
      Process.sleep(@stale_retry_delay)
      retry_on_stale(fun, attempts - 1)
  end
end

defmodule Support.Browser.Assertions do
  require Wallaby.Browser

  defmacro assert_text(session, text) do
    quote do
      Support.Browser.retry_on_stale(fn ->
        Wallaby.Browser.assert_text(unquote(session), unquote(text))
      end)

      unquote(session)
    end
  end

  defmacro assert_has(session, query) do
    quote do
      Support.Browser.retry_on_stale(fn ->
        Wallaby.Browser.assert_has(unquote(session), unquote(query))
      end)

      unquote(session)
    end
  end

  defmacro refute_has(session, query) do
    quote do
      Support.Browser.retry_on_stale(fn ->
        Wallaby.Browser.refute_has(unquote(session), unquote(query))
      end)

      unquote(session)
    end
  end
end
