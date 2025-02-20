# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Front.Decorators.Header.Workflow do
  alias Front.Models

  def tab_class(conn, tab_path) do
    if is_tab_active?(conn, tab_path) do
      "tab tab--active"
    else
      "tab"
    end
  end

  def is_tab_active?(conn, tab_path) do
    cond do
      is_tab_active?(conn, tab_path, "artifacts") ->
        true

      is_tab_active?(conn, tab_path, ~r"\/workflows\/(.+)/summary(.*)") ->
        true

      is_workflow_path?(tab_path) and is_workflow_path?(conn.request_path) ->
        true

      true ->
        false
    end
  end

  def summary(conn) do
    conn.assigns
    |> case do
      %{workflow: %{summary: %Models.TestSummary{} = summary}} ->
        total = Models.TestSummary.total(summary)
        passed = Models.TestSummary.passed(summary)
        failed = Models.TestSummary.failed(summary)
        skipped = Models.TestSummary.skipped(summary)

        partial =
          cond do
            failed > 0 ->
              """
              <span class="mh1">&middot;</span><span class="red normal">#{failed} failed</span>
              """

            passed > 0 ->
              """
              <span class="mh1">&middot;</span><span class="green normal">#{passed} passed</span>
              """

            true ->
              ""
          end

        if partial != "" do
          """
          <span data-tippy-content="#{total} tests: #{passed} passed, #{failed} failed, #{skipped} skipped"><span>Tests</span>#{partial}</span>
          """
        else
          """
          <span>Tests</span>
          """
        end

      _ ->
        """
        <span>Tests</span>
        """
    end
  end

  defp is_tab_active?(conn, tab_path, tab_name) do
    tab_path =~ tab_name and conn.request_path =~ tab_name
  end

  defp is_workflow_path?(path), do: path =~ ~r/^\/workflows\/[^\/]+\/?$/

  ### operation is used on the public workflow page
  # due to the historical reason of unstability of Branch API
  def safe(f) do
    f.()
  rescue
    _ -> ""
  end
end
