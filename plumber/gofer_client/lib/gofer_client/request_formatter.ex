defmodule GoferClient.RequestFormatter do
  @moduledoc """
  Module serves to transform data in proto message format suitable for communication
  via gRPC with Gofer service.
  """

  alias InternalApi.Gofer.{CreateRequest, PipelineDoneRequest, GitRefType}
  alias InternalApi.Gofer.DeploymentTargets.VerifyRequest
  alias Util.{ToTuple, Proto}

  # Create

  def form_create_request(yml_def_map, ppl_id, previous_ids, ref_args) do
    with {:switch_defined, targets_list}  when not is_nil(targets_list)
                        <-  {:switch_defined, Map.get(yml_def_map, "promotions")},
         {:ok, targets} <- revise_targets_defs(targets_list),
         switch_params  <- %{pipeline_id: ppl_id, prev_ppl_artefact_ids: previous_ids,
                             targets: targets} |> Map.merge(ref_args)
    do
      Proto.deep_new(CreateRequest, switch_params, string_keys_to_atoms: true,
           transformations: %{GitRefType => {__MODULE__, :string_to_enum_atom}})
    else
      {:switch_defined, nil} -> {:ok, :switch_not_defined}
      er = {:error, _e} -> er
      error -> {:error, error}
    end
  end

  def string_to_enum_atom(_field_name, field_value)
    when is_binary(field_value) and field_value != "" do
      field_value |> String.upcase() |> String.to_atom()
  end

  defp revise_targets_defs(targets_list) do
    targets_list
    |> Enum.map(fn target_def ->
      revise_target_def(target_def)
    end)
    |> ToTuple.ok()
  end

  defp revise_target_def(target_def) do
    target_def
    |> Enum.into(%{}, fn {key, val} ->
      case key do
        "pipeline_file" -> {"pipeline_path", val}
        "auto_promote_on" -> {"auto_trigger_on", val}
        "parameters" -> {"parameter_env_vars", revise_parameters(val)}
        "auto_promote" -> {"auto_promote_when", revise_auto_promote(val)}
        _ -> {key, val}
      end
    end)
  end

  defp revise_parameters(%{"env_vars" => env_vars}) do
    env_vars |> Enum.map(fn env_var ->
      case Map.get(env_var, "required") do
        nil -> Map.put(env_var, "required", true)
        _val -> env_var
      end
    end)
  end

  defp revise_auto_promote(%{"when" => exp}) when is_binary(exp), do: exp
  defp revise_auto_promote(%{"when" => exp}) when is_boolean(exp),
    do: exp |> Atom.to_string()

  # PipelineDone

  def form_pipeline_done_request(switch_id, _result, _result_reason)
    when is_nil(switch_id), do: {:ok, :switch_not_defined}

  def form_pipeline_done_request(switch_id, result, result_reason)
    when is_binary(switch_id) and is_binary(result) and is_binary(result_reason) do
    %{switch_id: switch_id, result: result, result_reason: result_reason}
    |> PipelineDoneRequest.new()
    |> ToTuple.ok()
  end
  def form_pipeline_done_request(switch_id, result, result_reason) do
    "One or more of these params: #{inspect switch_id}, #{inspect result} and #{inspect result_reason} is not string."
    |> ToTuple.error()
  end

  # Verify

  def form_verify_request(target_id, triggerer, git_ref_type, git_ref_label)
    when is_binary(target_id) and is_binary(triggerer) and is_binary(git_ref_type) and is_binary(git_ref_label) do
    verify_params = %{target_id: target_id, triggerer: triggerer, git_ref_type: git_ref_type, git_ref_label: git_ref_label}

    Proto.deep_new(VerifyRequest, verify_params,
      transformations: %{VerifyRequest.GitRefType => {__MODULE__, :string_to_enum_atom}})
  end
  def form_verify_request(target_id, triggerer, git_ref_type, git_ref_label) do
    "One or more of these params: #{inspect target_id}, #{inspect triggerer}, #{inspect git_ref_type} and #{inspect git_ref_label} is not in the expected format."
    |> ToTuple.error()
  end
end
