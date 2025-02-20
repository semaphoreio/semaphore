defmodule Support.Yaml do
  @moduledoc """
  Module serves to generate exemplary yaml definitions.
  """

  def valid_definition(params) do
    """
    apiVersion: v1.0
    kind: Schedule
    metadata:
      name: #{params.name}
    spec:
      project: #{params.project}
      branch: #{params.branch}
      at: #{params.at}
      pipeline_file: #{params.pipeline_file}
    """
  end
end
