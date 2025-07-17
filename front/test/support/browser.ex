defmodule Support.Browser do
  use Wallaby.DSL

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

  def scroll_into_view(session, css_selector) do
    session |> execute_script("document.querySelector('#{css_selector}').scrollIntoView()")
  end
end
