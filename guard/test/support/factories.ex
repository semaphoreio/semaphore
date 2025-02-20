defmodule Support.Factories do
  def user(meta \\ []) do
    meta_def = [
      status: status_ok(),
      name: "radwo",
      user_id: "78114608-be8a-465a-b9cd-81970fb802c6",
      email: "rwozniak@renderedtext.com",
      created_at: Google.Protobuf.Timestamp.new(seconds: 1),
      avatar_url: "https://s.gravatar.com/avatar/19fdbead2f7e3477649214240ff1540c",
      github_token: "1d130bfebcbb3240347d724ff4545b9a14797a6e",
      github_uid: "184065",
      github_scope: InternalApi.User.DescribeResponse.RepoScope.value(:PRIVATE),
      repository_providers: [
        InternalApi.User.RepositoryProvider.new(
          logn: "unknown",
          uid: "44306450",
          type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
          scope: InternalApi.User.RepositoryProvider.Scope.value(:PRIVATE)
        ),
        InternalApi.User.RepositoryProvider.new(
          logn: "radwo",
          uid: "184065",
          type: InternalApi.User.RepositoryProvider.Type.value(:GITHUB),
          scope: InternalApi.User.RepositoryProvider.Scope.value(:PRIVATE)
        )
      ],
      repository_scopes:
        InternalApi.User.RepositoryScopes.new(
          github:
            InternalApi.User.RepositoryScopes.RepositoryScope.new(
              scope: InternalApi.User.RepositoryScopes.RepositoryScope.Scope.value(:PRIVATE),
              login: "radwo",
              id: "184065"
            ),
          bitbucket:
            InternalApi.User.RepositoryScopes.RepositoryScope.new(
              scope: InternalApi.User.RepositoryScopes.RepositoryScope.Scope.value(:NONE),
              login: "",
              id: ""
            )
        )
    ]

    Keyword.merge(meta_def, meta) |> InternalApi.User.DescribeResponse.new()
  end

  def organization(params \\ []) do
    [
      org_id: "fa7ddb9f-1f67-4210-8f78-47062bdcbf21",
      org_username: "Semaphore",
      owner_id: "6623012f-593e-4437-98d6-1765e61d8c43",
      restricted: false,
      allowed_id_providers: ""
    ]
    |> Keyword.merge(params)
    |> InternalApi.Organization.Organization.new()
  end

  def status_ok do
    InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK))
  end
end
