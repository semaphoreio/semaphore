defmodule Support.Factories.Model do
  alias Secrethub.Model

  def prepare_content(params \\ []) do
    params
    |> prepare_content_params()
    |> Map.update!(:env_vars, fn env_vars ->
      Enum.into(env_vars, [], &struct(Model.EnvVar, &1))
    end)
    |> Map.update!(:files, fn files ->
      Enum.into(files, [], &struct(Model.File, &1))
    end)
    |> to_struct(Model.Content)
  end

  def prepare_content_params(params \\ []) do
    content_defaults()
    |> Keyword.merge(params)
    |> Keyword.take([:env_vars, :files])
    |> Map.new()
  end

  defp content_defaults do
    [
      env_vars: [
        %{name: "VAR1", value: "value1"},
        %{name: "VAR2", value: "value2"}
      ],
      files: [
        %{path: "/home/path1", content: "content1"},
        %{path: "/home/path2", content: "content2"}
      ]
    ]
  end

  def prepare_checkout(params \\ []) do
    params
    |> prepare_checkout_params()
    |> to_struct(Model.Checkout)
  end

  def prepare_checkout_params(params \\ []) do
    checkout_defaults()
    |> Keyword.merge(params)
    |> Keyword.take([:env_vars, :files])
    |> Map.new()
  end

  defp checkout_defaults do
    [
      job_id: Ecto.UUID.generate(),
      pipeline_id: Ecto.UUID.generate(),
      workflow_id: Ecto.UUID.generate(),
      hook_id: Ecto.UUID.generate(),
      project_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate()
    ]
  end

  defp to_struct(params, schema), do: struct(schema, params)
end
