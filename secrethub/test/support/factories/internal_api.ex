defmodule Support.Factories.InternalApi do
  def secret(name, id \\ "") do
    InternalApi.Secrethub.Secret.new(
      metadata:
        InternalApi.Secrethub.Secret.Metadata.new(
          name: name,
          description: "Some descsription of the secret",
          id: id
        ),
      data:
        InternalApi.Secrethub.Secret.Data.new(
          env_vars: [
            InternalApi.Secrethub.Secret.EnvVar.new(name: "A", value: "test"),
            InternalApi.Secrethub.Secret.EnvVar.new(name: "B", value: "test")
          ],
          files: [
            InternalApi.Secrethub.Secret.File.new(path: "/home/semaphore/a", content: "xyz"),
            InternalApi.Secrethub.Secret.File.new(path: "/home/semaphore/b", content: "dfg")
          ]
        )
    )
  end

  def with_org_options(
        secret = %InternalApi.Secrethub.Secret{},
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
          InternalApi.Secrethub.Secret.OrgConfig.new(
            projects_access: opts[:projects_access],
            project_ids: opts[:project_ids],
            debug_access: opts[:debug_access],
            attach_access: opts[:attach_access]
          )
    }
  end
end
