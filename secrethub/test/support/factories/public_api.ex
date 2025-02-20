defmodule Support.Factories.PublicApi do
  def secret(name) do
    alias Semaphore.Secrets.V1beta.Secret

    Secret.new(
      metadata: Secret.Metadata.new(name: name),
      data:
        Secret.Data.new(
          env_vars: [
            Secret.EnvVar.new(name: "A", value: "test"),
            Secret.EnvVar.new(name: "B", value: "test")
          ],
          files: [
            Secret.File.new(path: "/home/semaphore/a", content: "xyz"),
            Secret.File.new(path: "/home/semaphore/b", content: "dfg")
          ]
        )
    )
  end

  def with_org_options(
        secret,
        opts \\ []
      ) do
    default = [
      projects_access: :ALLOWED,
      project_ids: Support.Factories.Secret.project_ids(),
      debug_access: :JOB_DEBUG_NO,
      attach_access: :JOB_ATTACH_YES
    ]

    opts = Keyword.merge(default, opts)

    %{
      secret
      | :org_config =>
          Semaphore.Secrets.V1beta.Secret.OrgConfig.new(
            projects_access: opts[:projects_access],
            project_ids: opts[:project_ids],
            debug_access: opts[:debug_access],
            attach_access: opts[:attach_access]
          )
    }
  end
end
