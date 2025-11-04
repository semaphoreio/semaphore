defmodule Support.WallabyScreenshotFormatter do
  @behaviour ExUnit.Formatter

  def init(opts), do: {:ok, opts}

  def handle_cast(
        {:test_finished, %ExUnit.Test{state: {:failed, _}, name: name, tags: tags}},
        opts
      ) do
    if Wallaby.screenshot_on_failure?() do
      if pid = tags[:wallaby_test_pid] do
        Wallaby.Feature.Utils.take_screenshots_for_sessions(pid, Atom.to_string(name))
      end
    end

    {:noreply, opts}
  end

  def handle_cast(_event, opts), do: {:noreply, opts}
  def handle_info(_msg, opts), do: {:noreply, opts}
end
