defmodule Zebra.Workers.JobRequestFactory.OpenIDConnect do
  require Logger

  alias InternalApi.Secrethub.GenerateOpenIDConnectTokenRequest, as: Request
  alias InternalApi.Secrethub.SecretService.Stub
  alias Zebra.Workers.JobRequestFactory.JobRequest

  @rpc_opts [timeout: 30_000]

  def enabled?(org_id) do
    Application.get_env(:zebra, :environment) == :test ||
      FeatureProvider.feature_enabled?(:open_id_connect, param: org_id)
  end

  def load(job, repo_env_vars, org, job_type \\ :pipeline_job, spec_env_vars \\ []) do
    if enabled?(job.organization_id) do
      Watchman.benchmark("zebra.external.secrethub.generate_open_id_token", fn ->
        {wf_id, ppl_id} = find_wf_and_ppl_ids(job)

        repo = find_env_var(repo_env_vars, "SEMAPHORE_GIT_REPO_NAME")
        ref_type = find_env_var(repo_env_vars, "SEMAPHORE_GIT_REF_TYPE")
        ref = find_env_var(repo_env_vars, "SEMAPHORE_GIT_REF")

        req =
          Request.new(
            org_id: job.organization_id,
            expires_in: 24 * 3600,
            subject:
              "org:#{org.org_username}:project:#{job.project_id}:repo:#{repo}:ref_type:#{ref_type}:ref:#{ref}",
            project_id: job.project_id,
            workflow_id: wf_id,
            pipeline_id: ppl_id,
            job_id: job.id,
            repository_name: repo,
            git_tag: find_env_var(repo_env_vars, "SEMAPHORE_GIT_TAG"),
            git_ref: ref,
            git_ref_type: ref_type,
            git_branch_name: find_env_var(repo_env_vars, "SEMAPHORE_GIT_BRANCH"),
            git_pull_request_number: find_env_var(repo_env_vars, "SEMAPHORE_GIT_PR_NUMBER"),
            git_pull_request_branch: find_env_var(repo_env_vars, "SEMAPHORE_GIT_PR_BRANCH"),
            org_username: org.org_username,
            job_type: to_string(job_type),
            repo_slug: find_env_var(repo_env_vars, "SEMAPHORE_GIT_REPO_SLUG"),
            triggerer: construct_triggerer(wf_id, ppl_id, job.id, spec_env_vars, job_type)
          )

        with {:ok, ch} <- channel(),
             {:ok, res} <- Stub.generate_open_id_connect_token(ch, req, @rpc_opts) do
          {:ok, [JobRequest.env_var("SEMAPHORE_OIDC_TOKEN", res.token)]}
        else
          e ->
            Logger.info("Failed to fetch info for OIDC Token, #{inspect(e)}")

            {:error, :communication_error}
        end
      end)
    else
      {:ok, []}
    end
  end

  defp find_wf_and_ppl_ids(job) do
    if job.build_id do
      {:ok, task} = Zebra.Models.Task.find(job.build_id)

      {task.workflow_id, task.ppl_id}
    else
      # debug jobs don't have have this info
      {"", ""}
    end
  end

  defp find_env_var(env_vars, name) do
    var = Enum.find(env_vars, fn e -> e["name"] == name end)

    if is_nil(var) do
      ""
    else
      Base.decode64!(var["value"])
    end
  end

  def construct_triggerer(_wf_id, _ppl_id, _job_id, _env_vars, :project_debug_job), do: ""

  def construct_triggerer(wf_id, ppl_id, job_id, env_vars, job_type) do
    case wf_triggerer(wf_id, ppl_id, job_id, env_vars, job_type) do
      "" ->
        ""

      wf_triggerer ->
        wf_rerun = String.first("#{wf_rerun?(env_vars)}")
        ppl_triggerer = ppl_triggerer(env_vars)
        ppl_rerun = String.first("#{ppl_rerun?(env_vars)}")

        "#{wf_triggerer}:#{wf_rerun}-#{ppl_triggerer}:#{ppl_rerun}"
    end
  end

  defp wf_triggerer(wf_id, ppl_id, job_id, env_vars, job_type) do
    triggered_by_api = true_env_var?(env_vars, "SEMAPHORE_WORKFLOW_TRIGGERED_BY_API")
    triggered_by_hook = true_env_var?(env_vars, "SEMAPHORE_WORKFLOW_TRIGGERED_BY_HOOK")

    triggered_by_manual_run =
      true_env_var?(env_vars, "SEMAPHORE_WORKFLOW_TRIGGERED_BY_MANUAL_RUN")

    triggered_by_schedule = true_env_var?(env_vars, "SEMAPHORE_WORKFLOW_TRIGGERED_BY_SCHEDULE")

    case {triggered_by_api, triggered_by_schedule, triggered_by_manual_run, triggered_by_hook,
          job_type} do
      {true, _, _, _, _} ->
        "a"

      {_, true, _, _, _} ->
        "s"

      {_, _, true, _, _} ->
        "m"

      {_, _, _, true, _} ->
        "h"

      {_, _, _, _, :debug_job} ->
        ""

      _ ->
        Logger.error(
          "Invalid triggerer for wf_id: #{wf_id}, ppl_id: #{ppl_id}, job_id: #{job_id}"
        )

        raise "Invalid triggerer"
    end
  end

  defp wf_rerun?(env_vars), do: true_env_var?(env_vars, "SEMAPHORE_WORKFLOW_RERUN")

  defp ppl_triggerer(env_vars) do
    promoted_by = find_env_var(env_vars, "SEMAPHORE_PIPELINE_PROMOTED_BY")
    is_promotion = true_env_var?(env_vars, "SEMAPHORE_PIPELINE_PROMOTION")

    case {promoted_by, is_promotion} do
      {"auto-promotion", true} -> "u"
      {_, true} -> "n"
      _ -> "i"
    end
  end

  defp ppl_rerun?(env_vars), do: true_env_var?(env_vars, "SEMAPHORE_PIPELINE_RERUN")

  defp true_env_var?(env_vars, name), do: true?(find_env_var(env_vars, name))

  defp true?(value), do: value |> String.downcase() == "true"

  defp channel do
    {:ok, endpoint} = Application.fetch_env(:zebra, :secrethub_api_endpoint)

    GRPC.Stub.connect(endpoint)
  end
end
