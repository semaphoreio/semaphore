defmodule Front.Widgets.Factory do
  def create(widget), do: create(Map.fetch!(widget, "type") |> String.downcase(), widget)

  def create("list", widget), do: create("list_workflows", widget)

  def create("list_workflows", widget),
    do:
      {:list_workflows,
       widget |> Map.take(["filters", "name"]) |> Map.values() |> List.to_tuple()}

  def create("list_pipelines", widget),
    do:
      {:list_pipelines,
       widget |> Map.take(["filters", "name"]) |> Map.values() |> List.to_tuple()}

  def create("duration_pipelines", widget),
    do:
      {:duration_pipelines,
       widget |> Map.take(["filters", "name"]) |> Map.values() |> List.to_tuple()}

  def create("ratio_pipelines", widget),
    do:
      {:ratio_pipelines,
       widget |> Map.take(["filters", "name"]) |> Map.values() |> List.to_tuple()}
end
