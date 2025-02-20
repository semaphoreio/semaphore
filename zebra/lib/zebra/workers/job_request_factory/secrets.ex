defmodule Zebra.Workers.JobRequestFactory.Secrets do
  require Logger
  alias InternalApi.Secrethub.CheckoutManyRequest, as: CheckoutRequest
  alias InternalApi.Secrethub.DescribeManyRequest, as: DescribeRequest
  alias InternalApi.Secrethub.RequestMeta, as: Meta
  alias InternalApi.Secrethub.CheckoutMetadata
  alias InternalApi.Secrethub.SecretService.Stub
  alias Zebra.Workers.JobRequestFactory.JobRequest

  defstruct [
    :job_secrets,
    :image_pull_secrets,
    :container_secrets
  ]

  defmodule Secret do
    defstruct [
      :name,
      :env_vars,
      :files
    ]

    def new(api_secret) do
      %Secret{
        name: api_secret.metadata.name,
        env_vars:
          api_secret.data.env_vars
          |> Enum.map(fn env_var ->
            JobRequest.env_var(env_var.name, env_var.value)
          end),
        files:
          api_secret.data.files
          |> Enum.map(fn file ->
            JobRequest.file(file.path, file.content, "0644", encode_to_base64: false)
          end)
      }
    end
  end

  def load(org_id, job_id, spec, project, repo_proxy) do
    Watchman.benchmark("zebra.external.secrethub.checkout_many", fn ->
      # We want to fetch all necessary secrets from Secrethub in
      # one big checkout_many request to increase network efficiency.

      # regular job secrets
      job_secret_names = Enum.map(spec.secrets, & &1.name)

      # image pull secrets
      image_pull_secret_names = Enum.map(spec.agent.image_pull_secrets, & &1.name)

      # container secrets
      container_secret_names =
        Enum.flat_map(spec.agent.containers, fn c ->
          Enum.map(c.secrets, & &1.name)
        end)

      names =
        (job_secret_names ++ image_pull_secret_names ++ container_secret_names)
        |> filter_names(project, repo_proxy)

      checkout_metadata = prepare_checkout_metadata(job_id, spec, repo_proxy)

      load_based_on_names(org_id, names, spec, checkout_metadata)
    end)
  end

  def validate_job_secrets(org_id, spec, operation) do
    # regular job secrets
    job_secret_names = Enum.map(spec.secrets, & &1.name)

    load_secrets(org_id, spec.project_id, job_secret_names)
    |> validate_secrets(job_secret_names, operation)
  end

  defp load_based_on_names(_, [], spec, _checkout_meta_params) do
    new([], spec)
  end

  defp load_based_on_names(org_id, names, spec, checkout_meta_params) do
    meta = Meta.new(api_version: "v1beta", req_id: UUID.uuid4(), org_id: org_id)

    checkout_meta = CheckoutMetadata.new(checkout_meta_params)

    req =
      CheckoutRequest.new(
        metadata: meta,
        names: names,
        checkout_metadata: checkout_meta,
        project_id: spec.project_id
      )

    with {:ok, endpoint} <- Application.fetch_env(:zebra, :secrethub_api_endpoint),
         {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- Stub.checkout_many(channel, req, timeout: 30_000) do
      secrets = response.secrets
      loaded_secret_names = Enum.map(secrets, & &1.metadata.name)

      missing_secret_names =
        MapSet.difference(
          MapSet.new(names),
          MapSet.new(loaded_secret_names)
        )

      if MapSet.size(missing_secret_names) == 0 do
        secrets = Enum.map(secrets, fn s -> Secret.new(s) end)

        new(secrets, spec)
      else
        msg =
          missing_secret_names
          |> Enum.map_join(", ", fn name -> "Secret #{name} not found" end)

        {:stop_job_processing, msg}
      end
    else
      e ->
        Logger.info("Failed to fetch info for Secrets##{names}, #{inspect(e)}")

        {:error, :communication_error}
    end
  end

  defp load_secrets(_, _, []), do: {:ok, []}

  defp load_secrets(org_id, project_id, names) do
    meta = Meta.new(api_version: "v1beta", req_id: UUID.uuid4(), org_id: org_id)

    req =
      DescribeRequest.new(
        metadata: meta,
        names: names,
        project_id: project_id
      )

    with {:ok, endpoint} <- Application.fetch_env(:zebra, :secrethub_api_endpoint),
         {:ok, channel} <- GRPC.Stub.connect(endpoint),
         {:ok, response} <- Stub.describe_many(channel, req, timeout: 30_000) do
      {:ok, response.secrets}
    else
      e ->
        Logger.info("Failed to fetch info for Secrets##{inspect(names)}, #{inspect(e)}")

        {:error,
         "Something went wrong while loading secrets. Please try again later. If the issue still persists contact support."}
    end
  end

  defp validate_secrets({:error, msg}, _, _), do: {:error, msg}
  defp validate_secrets({:ok, []}, _, _), do: {:ok, true}

  defp validate_secrets({:ok, secrets}, names, operation) do
    is_permitted =
      secrets
      |> validator(operation)

    loaded_secret_names = Enum.map(secrets, & &1.metadata.name)

    missing_secret_names =
      MapSet.difference(
        MapSet.new(names),
        MapSet.new(loaded_secret_names)
      )

    all_secrets_returned = MapSet.size(missing_secret_names) == 0
    {:ok, is_permitted and all_secrets_returned}
  end

  defp validator(secrets, :attach) do
    secrets
    |> Enum.reduce_while(true, fn s, _ ->
      if !is_nil(s.org_config) and
           s.org_config.attach_access ==
             InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_NO) do
        {:halt, false}
      else
        {:cont, true}
      end
    end)
  end

  defp validator(secrets, :debug) do
    secrets
    |> Enum.reduce_while(true, fn s, _ ->
      if !is_nil(s.org_config) and
           s.org_config.debug_access ==
             InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_NO) do
        {:halt, false}
      else
        {:cont, true}
      end
    end)
  end

  defp new(loaded_secrets, spec) do
    with {:ok, job_secrets} <- select(loaded_secrets, Enum.map(spec.secrets, & &1.name)),
         {:ok, image_pull_secrets} <-
           select(loaded_secrets, Enum.map(spec.agent.image_pull_secrets, & &1.name)),
         {:ok, container_secrets} <- new_container_secrets(loaded_secrets, spec.agent.containers) do
      {:ok,
       %__MODULE__{
         job_secrets: job_secrets,
         image_pull_secrets: image_pull_secrets,
         container_secrets: container_secrets
       }}
    else
      e -> e
    end
  end

  #
  # Returns either:
  #
  # - {:ok, [list of list of secrets]}
  #
  #   Each entry in the result corresponds to a list of secrets for a container.
  #
  #   The 0th index contains a list of secrets for the 0th container.
  #   The 1th index contains a list of secrets for the 1th container.
  #   The nth index contains a list of secrets for the nth container.
  #
  # - {:error, reason}
  #
  defp new_container_secrets(loaded_secrets, containers) do
    results =
      Enum.map(containers, fn c ->
        names = Enum.map(c.secrets, & &1.name)

        select(loaded_secrets, names)
      end)

    errors =
      Enum.filter(results, fn {status, _} ->
        status != :ok
      end)

    if errors == [] do
      secrets_without_status = Enum.map(results, fn {_, secrets} -> secrets end)

      {:ok, secrets_without_status}
    else
      hd(errors)
    end
  end

  defp select(loaded_secrets, names) do
    secrets =
      Enum.map(names, fn name ->
        Enum.find(loaded_secrets, fn s -> s.name == name end)
      end)
      |> Enum.reject(&is_nil/1)

    {:ok, secrets}
  end

  defp filter_names(names, _, nil), do: names

  defp filter_names(names, project, repo_proxy) do
    if forked_pr?(repo_proxy) do
      allowed = project.forked_pull_requests.allowed_secrets
      MapSet.intersection(MapSet.new(names), MapSet.new(allowed)) |> Enum.into([])
    else
      names
    end
  end

  defp forked_pr?(repo_proxy) do
    InternalApi.RepoProxy.Hook.Type.key(repo_proxy.git_ref_type) == :PR and
      repo_proxy.pr_slug != repo_proxy.repo_slug
  end

  defp prepare_checkout_metadata(job_id, spec, repo_proxy) do
    from_env = get_checkout_meta_from_env(spec.env_vars)
    from_repo = get_checkout_meta_from_repo(repo_proxy)

    from_env ++ from_repo ++ [job_id: job_id]
  end

  # extracts pipeline_id and workflow_id from job spec env_vars
  defp get_checkout_meta_from_env(vars) do
    vars
    |> Enum.filter(fn v ->
      Enum.member?(["SEMAPHORE_PIPELINE_ID", "SEMAPHORE_WORKFLOW_ID"], v.name)
    end)
    |> Enum.map(
      &if &1.name == "SEMAPHORE_PIPELINE_ID",
        do: {:pipeline_id, &1.value},
        else: {:workflow_id, &1.value}
    )
  end

  defp get_checkout_meta_from_repo(nil), do: []

  defp get_checkout_meta_from_repo(repo_proxy) do
    [hook_id: repo_proxy.hook_id, user_id: repo_proxy.user_id]
  end
end
