defmodule Secrethub.Utils do
  alias Semaphore.Secrets.V1beta.Secret, as: PublicApiSecret
  alias InternalApi.Secrethub.Secret, as: InternalApiSecret

  def to_map_with_string_keys(map) do
    map |> Poison.encode!() |> Poison.decode!()
  end

  def consolidate_org_configs(new_config, old_secret) do
    case new_config do
      nil -> take_org_config(old_secret)
      config -> permissions_from_org_config(config)
    end
  end

  defp take_org_config(secret) do
    secret
    |> Map.take(~w(all_projects project_ids job_debug job_attach)a)
  end

  def permissions_from_org_config(org_config) do
    projects_permissions = projects_permissions(org_config)
    access_permissions = access_permissions(org_config)

    Map.merge(projects_permissions, access_permissions)
  end

  def projects_permissions(nil), do: %{all_projects: nil, project_ids: nil}

  def projects_permissions(%{projects_access: projects_access, project_ids: project_ids})
      when projects_access in [:ALL, :ALLOWED, :NONE] and is_list(project_ids) do
    all_projects = projects_access == :ALL

    project_ids =
      if projects_access == :NONE,
        do: [],
        else: project_ids

    %{all_projects: all_projects, project_ids: project_ids}
  end

  def projects_permissions(%{}) do
    %{all_projects: nil, project_ids: nil}
  end

  def access_permissions(nil), do: %{job_debug: nil, job_attach: nil}

  def access_permissions(%InternalApiSecret.OrgConfig{
        debug_access: debug_access,
        attach_access: attach_access
      }) do
    job_debug = InternalApiSecret.OrgConfig.JobDebugAccess.value(debug_access)
    job_attach = InternalApiSecret.OrgConfig.JobAttachAccess.value(attach_access)

    %{job_debug: job_debug, job_attach: job_attach}
  end

  def access_permissions(%{debug_access: debug_access, attach_access: attach_access}) do
    job_debug = PublicApiSecret.OrgConfig.JobDebugAccess.value(debug_access)
    job_attach = PublicApiSecret.OrgConfig.JobAttachAccess.value(attach_access)

    %{job_debug: job_debug, job_attach: job_attach}
  end

  def access_permissions(%{}) do
    %{job_debug: nil, job_attach: nil}
  end

  def to_org_config_params(params) do
    project_access(params) ++
      job_access(params)
  end

  def project_access(%{all_projects: nil, project_ids: nil}), do: []

  def project_access(%{all_projects: all_projects, project_ids: project_ids}) do
    project_access =
      if all_projects,
        do: :ALL,
        else: if(project_ids == [], do: :NONE, else: :ALLOWED)

    [
      projects_access: project_access,
      project_ids: project_ids
    ]
  end

  def job_access(%{job_debug: job_debug, job_attach: job_attach})
      when is_nil(job_debug) or is_nil(job_attach) do
    []
  end

  def job_access(%{job_debug: job_debug, job_attach: job_attach}) do
    api_job_debug = InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess.key(job_debug)
    api_job_attach = InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess.key(job_attach)

    [
      debug_access: api_job_debug,
      attach_access: api_job_attach
    ]
  end
end
