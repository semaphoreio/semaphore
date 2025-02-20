defmodule Support.Factories.Secret do
  @org_id Ecto.UUID.generate()

  require Logger

  @env_vars [
    %{name: "aws_id", value: "21"},
    %{name: "aws_token", value: "42is2times21"}
  ]

  @files [
    %{path: "/home/semaphore/a", content: "21"},
    %{path: "/home/semaphore/a/b/c", content: "42is2times21"}
  ]

  @project_ids [
    Ecto.UUID.generate(),
    Ecto.UUID.generate()
  ]

  alias InternalApi.Secrethub.Secret

  def clear do
    Secrethub.Secret |> Secrethub.Repo.all() |> Enum.each(fn s -> Secrethub.Repo.delete(s) end)
  end

  def create(
        name,
        org_id \\ @org_id,
        env_vars \\ @env_vars,
        files \\ @files,
        all \\ true,
        project_ids \\ [],
        job_debug \\ Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_NO),
        job_attach \\ Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_YES)
      ) do
    content = %{
      data: %{
        env_vars: env_vars,
        files: files
      }
    }

    changeset =
      Secrethub.Secret.changeset(%Secrethub.Secret{}, %{
        name: name,
        org_id: org_id,
        content: Secrethub.Utils.to_map_with_string_keys(content),
        all_projects: all,
        project_ids: project_ids,
        job_debug: job_debug,
        job_attach: job_attach,
        created_by: Ecto.UUID.generate()
      })

    with {:ok, secret} <- Secrethub.Repo.insert(changeset),
         {:ok, secret} <- Secrethub.Encryptor.decrypt_secret(secret) do
      {:ok, secret}
    else
      e -> {:error, e}
    end
  end

  def insert(name, org_id, params \\ []) do
    default_content = %{
      data: %{
        env_vars: @env_vars,
        files: @files
      }
    }

    default_params = %{
      name: name,
      org_id: org_id,
      content: default_content,
      all_projects: true,
      project_ids: [],
      job_debug: Secret.OrgConfig.JobDebugAccess.value(:JOB_DEBUG_NO),
      job_attach: Secret.OrgConfig.JobAttachAccess.value(:JOB_ATTACH_YES)
    }

    input_params = Map.merge(default_params, Map.new(params))
    content_validated = Map.get(input_params.content, :data, %{})
    input_params = Map.put(input_params, :content, content_validated)

    case Secrethub.Encryptor.encrypt(Poison.encode!(content_validated), name) do
      {:ok, encrypted} ->
        input_params = Map.put(input_params, :content_encrypted, encrypted)
        struct(Secrethub.Secret, input_params) |> Secrethub.Repo.insert()

      e ->
        {:error, e}
    end
  end

  def project_ids, do: @project_ids

  def with_project(name, org_id \\ @org_id, all \\ false, project_ids \\ @project_ids) do
    {:ok, secret} = create(name, org_id, @env_vars, @files, all, project_ids)
    {:ok, secret, project_ids}
  end
end
