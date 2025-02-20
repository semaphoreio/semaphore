defmodule Ppl.PplSubInits.STMHandler.Compilation.Decider do
  @moduledoc """
  Decides wether the given pipeline needs to go through compilation phase
  """

  @spc_expression_pattern "([$%])({{([^(}})]+)}})"

  def decide_on_compilation(nil, _),
    do: {:ok, "compilation"}

  def decide_on_compilation(definition, pre_flight_checks) do
    cond do
      should_go_to_compilation?(definition) -> {:ok, "compilation"}
      pre_flight_checks_defined?(pre_flight_checks) -> {:ok, "compilation"}
      true -> {:ok, "regular_init"}
    end
  end

  defp should_go_to_compilation?(definition) when is_map(definition) do
    Enum.reduce_while(definition, false, fn {key, val}, acc ->
      cond do
        when_with_change_in(key, val)  -> {:halt, true}

        templates_expression(key, val) -> {:halt, true}

        uses_commands_files(key)       -> {:halt, true}

        should_go_to_compilation?(val) -> {:halt, true}

        true -> {:cont, acc}
      end
    end)
  end

  defp should_go_to_compilation?(definition) when is_list(definition) do
    Enum.reduce_while(definition, false, fn val, acc ->
      if should_go_to_compilation?(val) do
        {:halt, true}
      else
        {:cont, acc}
      end
    end)
  end

  defp should_go_to_compilation?(_definition), do: false

  def pre_flight_checks_defined?(:undefined), do: false
  def pre_flight_checks_defined?(pre_flight_checks) do
    org_pfc_defined? = not is_nil(pre_flight_checks |> Map.get("organization_pfc"))
    prj_pfc_defined? = not is_nil(pre_flight_checks |> Map.get("project_pfc"))
    org_pfc_defined? or prj_pfc_defined?
  end

  defp when_with_change_in("when", val) when is_binary(val),
    do: String.contains?(val, "change_in")

  defp when_with_change_in(_, _), do: false

  def templates_expression(name, val) when name != "commands" and is_binary(val) do
    Regex.match?(~r/#{@spc_expression_pattern}/, val)
  end
  def templates_expression(_, _), do: false

  defp uses_commands_files("commands_file"), do: true
  defp uses_commands_files(_field), do: false
end
