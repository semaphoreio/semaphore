defmodule Support.Factories do
  def project(meta \\ []) do
    alias InternalApi.Projecthub.Project.Status

    meta_def = [
      id: "ee2e6241-f30b-4892-a0d5-bd900b713430",
      name: "rbac",
      owner_id: "78114608-be8a-465a-b9cd-81970fb802c7",
      org_id: "8cbf8429-4230-4973-8d65-1e98b7d2ca64"
    ]

    # transform to map
    meta = Keyword.merge(meta_def, meta) |> Map.new()
    meta = struct(InternalApi.Projecthub.Project.Metadata, meta)

    spec =
      %{
        repository: %InternalApi.Projecthub.Project.Spec.Repository{
          id: "1e2e6241-f30b-4892-a0d5-bd900b713430",
          url: "git@github.com:renderedtext/rbac.git",
          name: "rbac",
          owner: "renderedtext"
        }
      }

    spec = struct(InternalApi.Projecthub.Project.Spec, spec)

    ready = %Status{state: :READY}
    %InternalApi.Projecthub.Project{metadata: meta, spec: spec, status: ready}
  end

  def response_meta(code \\ :OK) do
    %InternalApi.Projecthub.ResponseMeta{
      status: %InternalApi.Projecthub.ResponseMeta.Status{
        code: code
      }
    }
  end

  def user(meta \\ []) do
    meta_def = %{
      status: %InternalApi.ResponseStatus{code: :OK},
      name: "radwo",
      user_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      email: "rwozniak@renderedtext.com",
      created_at: %Google.Protobuf.Timestamp{seconds: 1},
      avatar_url: "https://s.gravatar.com/avatar/19fdbead2f7e3477649214240ff1540c",
      github_token: "1d130bfebcbb3240347d724ff4545b9a14797a6e",
      github_uid: "184065",
      github_scope: :PRIVATE,
      repository_providers: [
        %InternalApi.User.RepositoryProvider{
          login: "unknown",
          uid: "44306450",
          type: :GITHUB,
          scope: :PRIVATE
        },
        %InternalApi.User.RepositoryProvider{
          login: "radwo",
          uid: "184065",
          type: :GITHUB,
          scope: :PRIVATE
        }
      ],
      repository_scopes: %InternalApi.User.RepositoryScopes{
        github: %InternalApi.User.RepositoryScopes.RepositoryScope{
          scope: :PRIVATE,
          login: "radwo",
          uid: "184065"
        },
        bitbucket: %InternalApi.User.RepositoryScopes.RepositoryScope{
          scope: :NONE,
          login: "",
          uid: ""
        }
      }
    }

    params =
      meta
      |> Map.new()
      |> then(&Map.merge(meta_def, &1))

    struct(InternalApi.User.DescribeResponse, params)
  end
end
