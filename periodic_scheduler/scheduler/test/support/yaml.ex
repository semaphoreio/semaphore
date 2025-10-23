defmodule Support.Yaml do
  @moduledoc """
  Module serves to generate exemplary yaml definitions.
  """

  def valid_definition(params) do
    version = Map.get(params, :version, "v1.0")
    branch_or_reference_field = if version == "v1.2", do: "reference", else: "branch"
    branch_or_reference_value = Map.get(params, :reference, Map.get(params, :branch, "master"))

    """
    apiVersion: #{version}
    kind: Schedule
    metadata:
      name: #{params.name}
    spec:
      project: #{params.project}
      #{branch_or_reference_field}: #{branch_or_reference_value}
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
    """
  end
end
