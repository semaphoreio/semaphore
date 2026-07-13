defmodule Projecthub.ParamsChecker do
  def run(spec, open_source, sem_approve_feature_enabled \\ true) do
    []
    |> validate_public_status(spec, open_source)
    |> validate_sem_approve_options(spec, sem_approve_feature_enabled)
    |> case do
      [] -> :ok
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  defp validate_public_status(errors, spec, open_source) do
    public = Map.get(spec, :visibility) == :PUBLIC

    if !public && open_source do
      ["Only public projects are allowed" | errors]
    else
      errors
    end
  end

  # When the `sem_approve_options` feature is disabled for the org, the options
  # are ignored/forced-false downstream, so there is nothing to validate here.
  defp validate_sem_approve_options(errors, _spec, false), do: errors

  defp validate_sem_approve_options(errors, spec, true) do
    if sem_approve_options_enabled?(spec) do
      errors
      |> validate_forked_pr_enabled(spec)
      |> validate_allowed_contributors_present(spec)
    else
      errors
    end
  end

  defp validate_forked_pr_enabled(errors, spec) do
    if build_forked_pr_enabled?(spec) do
      errors
    else
      ["Sem-approve options require forked pull requests to be enabled" | errors]
    end
  end

  defp validate_allowed_contributors_present(errors, spec) do
    if allowed_contributors_present?(spec) do
      errors
    else
      ["Sem-approve options require at least one trusted contributor" | errors]
    end
  end

  defp sem_approve_options_enabled?(spec) do
    forked_pull_requests = forked_pull_requests_settings(spec)

    map_get(forked_pull_requests, :allow_sem_approve_include_secrets, false) ||
      map_get(forked_pull_requests, :allow_sem_approve_enable_cache, false)
  end

  defp build_forked_pr_enabled?(spec) do
    repository = map_get(spec, :repository, %{})
    run_on = repository |> map_get(:run_on, []) |> List.wrap()

    Enum.any?(run_on, &forked_pull_request_run_type?/1)
  end

  defp forked_pull_request_run_type?(run_type) when is_integer(run_type) do
    run_type ==
      InternalApi.Projecthub.Project.Spec.Repository.RunType.value(:FORKED_PULL_REQUESTS)
  end

  defp forked_pull_request_run_type?(:FORKED_PULL_REQUESTS), do: true
  defp forked_pull_request_run_type?("FORKED_PULL_REQUESTS"), do: true
  defp forked_pull_request_run_type?(_), do: false

  defp allowed_contributors_present?(spec) do
    spec
    |> forked_pull_requests_settings()
    |> map_get(:allowed_contributors, [])
    |> Enum.any?(fn contributor ->
      case contributor do
        nil -> false
        _ -> String.trim(to_string(contributor)) != ""
      end
    end)
  end

  defp forked_pull_requests_settings(spec) do
    spec
    |> map_get(:repository, %{})
    |> map_get(:forked_pull_requests, %{})
  end

  defp map_get(map, key, default) when is_map(map) do
    Map.get(map, key, default)
  end

  defp map_get(_, _, default) do
    default
  end
end
