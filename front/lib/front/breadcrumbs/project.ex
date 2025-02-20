defmodule Front.Breadcrumbs.Project do
  def construct(assigns, conn, page) do
    breadcrumbs = [
      %{
        name: conn.assigns.project.name,
        url: "/projects/#{conn.assigns.project.name}",
        last: false
      },
      %{name: construct_crumb(page), last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end

  defp construct_crumb(:project), do: "Activity"
  defp construct_crumb(:artifacts), do: "Artifacts"
  defp construct_crumb(:scheduler), do: "Scheduler"
  defp construct_crumb(:insights), do: "Insights"
  defp construct_crumb(:deployments), do: "Deployments"
  defp construct_crumb(:people), do: "People"
  defp construct_crumb(:settings), do: "Settings"
  defp construct_crumb(:flaky_tests), do: "Flaky Tests"
end
