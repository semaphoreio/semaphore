defmodule Dashboardhub.Utils do
  require Logger

  def proto_to_record(proto) do
    alias Semaphore.Dashboards.V1alpha.Dashboard

    dashboard = %Dashboard{
      metadata: %Dashboard.Metadata{
        id: proto.metadata.id,
        name: proto.metadata.name,
        title: titleize(proto.metadata.name, proto.metadata.title)
      },
      spec: %Dashboard.Spec{
        widgets:
          proto.spec.widgets
          |> Enum.map(fn widget ->
            %Dashboard.Spec.Widget{
              name: widget.name,
              type: widget.type,
              filters: widget.filters
            }
          end)
      }
    }

    to_map_with_string_keys(dashboard)
  end

  def record_to_proto(record, module \\ Semaphore.Dashboards.V1alpha.Dashboard) do
    metadata =
      record.content["metadata"]
      |> Map.put("id", record.id)
      |> Map.put("create_time", record.inserted_at)
      |> Map.put("update_time", record.updated_at)
      |> Map.put("org_id", record.org_id)

    content = Map.put(record.content, "metadata", metadata)

    map_to_dashboard(content, module)
  end

  def uuid?(string) do
    String.match?(string, ~r/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/)
  end

  def valid_widgets?(dashboard) do
    valid_widgets = ["list_pipelines", "list_workflows", "duration_pipelines", "ratio_pipelines"]

    valid_filters = %{
      ratio_pipelines: ["project_id", "branch", "pipeline_file"],
      duration_pipelines: ["project_id", "branch", "pipeline_file"],
      list_pipelines: ["project_id", "branch", "pipeline_file"],
      list_workflows: ["project_id", "branch", "github_uid"]
    }

    if valid_widgets_names?(dashboard.spec.widgets, valid_widgets) do
      case list_widgets_with_invalid_filters(dashboard.spec.widgets, valid_filters) do
        [] ->
          {:ok, :valid}

        widgets ->
          message =
            widgets
            |> Enum.map(& &1.type)
            |> Enum.uniq()
            |> Enum.map_join(", ", fn type ->
              "widget #{type} should have only these filters #{valid_filters |> Map.fetch!(type |> String.to_atom()) |> Enum.join(", ")}"
            end)

          {:error, :invalid_widgets, message}
      end
    else
      {:error, :invalid_widgets,
       "widget type should be one of #{valid_widgets |> Enum.join(", ")}"}
    end
  end

  defp valid_widgets_names?(widgets, valid_widgets) do
    widgets
    |> Enum.map(& &1.type)
    |> Enum.all?(fn n -> Enum.member?(valid_widgets, n) end)
  end

  defp list_widgets_with_invalid_filters(widgets, valid_filters) do
    widgets
    |> Enum.filter(fn widget ->
      keys = widget.filters |> Map.keys()
      filters = valid_filters |> Map.fetch!(widget.type |> String.to_atom())

      not Enum.all?(keys, fn filter -> Enum.member?(filters, filter) end)
    end)
  end

  defp to_map_with_string_keys(map) do
    map |> Poison.encode!() |> Poison.decode!()
  end

  defp map_to_dashboard(dashboard, module) do
    dashboard = to_map_with_string_keys(dashboard)

    metadata_module = Module.concat(module, Metadata)
    spec_module = Module.concat(module, Spec)
    widget_module = Module.concat(module, Spec.Widget)

    metadata =
      struct(metadata_module, %{
        id: dashboard["metadata"]["id"],
        name: dashboard["metadata"]["name"],
        title: dashboard["metadata"]["title"],
        org_id: dashboard["metadata"]["org_id"],
        create_time: unix_timestamp(dashboard["metadata"]["create_time"]),
        update_time: unix_timestamp(dashboard["metadata"]["update_time"])
      })

    widgets =
      Enum.map(dashboard["spec"]["widgets"], fn widget ->
        struct(widget_module, %{
          name: widget["name"],
          type: widget["type"],
          filters: widget["filters"]
        })
      end)

    spec = struct(spec_module, %{widgets: widgets})

    struct(module, %{metadata: metadata, spec: spec})
  end

  defp titleize(name, ""), do: titleize(name)
  defp titleize(_name, title), do: title

  defp titleize(name) do
    name
    |> String.replace("-", " ")
    |> String.split()
    |> Enum.map_join(" ", &(&1 |> String.capitalize()))
  end

  def unix_timestamp(ecto_time) do
    ecto_time
    |> NaiveDateTime.from_iso8601!()
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end
end
