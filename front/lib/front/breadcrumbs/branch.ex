defmodule Front.Breadcrumbs.Branch do
  def construct(assigns) do
    breadcrumbs = [
      %{name: assigns.project.name, url: "/projects/#{assigns.project.name}", last: false},
      %{name: assigns.branch.display_name, last: true}
    ]

    Map.put(assigns, :breadcrumbs, breadcrumbs)
  end
end
