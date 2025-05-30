defmodule Support.Stubs.User do
  #
  # TODO: This stub is not complete. Some values are still hardcoded. DO NOT COPY.
  #
  # Hardcoding id values and API responses does not scale well. The more tests
  # we add that really on hardcoding, the harder it will become to untangle
  # the tests in the future.
  #

  alias Support.Stubs.{DB, Time, UUID}

  def default_user_id, do: "78114608-be8a-465a-b9cd-81970fb802c5"

  def init do
    DB.add_table(:users, [:id, :api_model])
    DB.add_table(:favorites, [:user_id, :organization_id, :favorite_id, :kind])

    __MODULE__.Grpc.init()
  end

  def switch_params(user, params) do
    new_user = params |> Keyword.merge(id: user.id) |> build()

    DB.update(:users, %{
      id: user.id,
      api_model: new_user
    })
  end

  def create_default(params \\ []) do
    defaults = [
      user_id: default_user_id(),
      github_repositry_scope: "private"
    ]

    defaults |> Keyword.merge(params) |> create()
  end

  def create(params \\ []) do
    user = build(params)

    DB.insert(:users, %{
      id: user.user_id,
      api_model: user
    })
  end

  alias InternalApi.User.RepositoryProvider
  defp map_repository_provider_scope("email"), do: RepositoryProvider.Scope.value(:EMAIL)
  defp map_repository_provider_scope("public"), do: RepositoryProvider.Scope.value(:PUBLIC)
  defp map_repository_provider_scope("private"), do: RepositoryProvider.Scope.value(:PRIVATE)
  defp map_repository_provider_scope(_), do: RepositoryProvider.Scope.value(:NONE)

  alias InternalApi.User.DescribeResponse.RepoScope
  defp map_github_scope("public"), do: RepoScope.value(:PUBLIC)
  defp map_github_scope("private"), do: RepoScope.value(:PRIVATE)
  defp map_github_scope(_), do: RepoScope.value(:NONE)

  def build(params \\ []) do
    params_with_defaults =
      [
        status: %InternalApi.ResponseStatus{
          code: InternalApi.ResponseStatus.Code.value(:OK),
          message: ""
        },
        user_id: UUID.gen(),
        name: "Milica",
        email: "dhh@basecamp.com",
        created_at: Time.now(),
        avatar_url: "https://gravatar.com/avatar/c716c3715a66612b070b6408b89c1190.png",
        api_token: "q8u38dj3dd83jd83j",
        github_token: "c716c3715a66612b070b6408b89c1190",
        github_scope: map_github_scope(params[:github_repositry_scope]),
        github_login: "milica-nerlovic",
        company: "RenderedText",
        repository_providers: [
          %RepositoryProvider{
            type: RepositoryProvider.Type.value(:GITHUB),
            scope: map_repository_provider_scope(params[:github_repositry_scope]),
            login: "milica-nerlovic",
            uid: "21684087"
          },
          %RepositoryProvider{
            type: RepositoryProvider.Type.value(:BITBUCKET),
            scope: map_repository_provider_scope(params[:bitbucket_repositry_scope]),
            login: "radwo",
            uid: "sdasd"
          }
        ],
        user: build_user()
      ]
      |> Keyword.merge(params)

    struct(InternalApi.User.DescribeResponse, params_with_defaults)
  end

  def build_user(params \\ []) do
    params_with_defaults =
      [
        id: UUID.gen(),
        username: "milica-nerlovic",
        name: "Milica",
        avatar_url: "https://gravatar.com/avatar/c716c3715a66612b070b6408b89c1190.png",
        github_uid: "githubuid",
        api_token: "skjelkejfde",
        github_login: "milica-nerlovic",
        single_org_user: false
      ]
      |> Keyword.merge(params)

    struct(InternalApi.User.User, params_with_defaults)
  end

  def delete(user_id) do
    DB.delete(:users, user_id)
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(UserMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(UserMock, :describe_many, &__MODULE__.describe_many/2)
      GrpcMock.stub(UserMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(UserMock, :regenerate_token, &__MODULE__.regenerate_token/2)
      GrpcMock.stub(UserMock, :list_favorites, &__MODULE__.list_favorites/2)
      GrpcMock.stub(UserMock, :create_favorite, &__MODULE__.create_favorite/2)
      GrpcMock.stub(UserMock, :delete_favorite, &__MODULE__.delete_favorite/2)
      GrpcMock.stub(UserMock, :check_github_token, &__MODULE__.check_github_token/2)

      GrpcMock.stub(
        UserMock,
        :refresh_repository_provider,
        &__MODULE__.refresh_repository_provider/2
      )
    end

    def describe(req, _) do
      user = DB.find(:users, req.user_id)

      if user do
        user.api_model
      else
        %InternalApi.User.DescribeResponse{status: internal_status(:BAD_PARAM)}
      end
    end

    def describe_many(req, _) do
      alias InternalApi.User.DescribeManyResponse, as: Response

      users =
        DB.all(:users)
        |> Enum.filter(fn u -> Enum.member?(req.user_ids, u.id) end)
        |> DB.extract(:api_model)
        |> Enum.map(fn u ->
          %InternalApi.User.User{
            id: u.user_id,
            avatar_url: u.avatar_url,
            github_uid: u.github_uid,
            name: u.name,
            company: u.company,
            email: u.email,
            repository_providers: u.repository_providers
          }
        end)

      %Response{status: internal_status(:OK), users: users}
    end

    def update(req, _) do
      user = DB.find(:users, req.user.id)

      if user do
        DB.update(:users, %{
          id: req.user.id,
          api_model: user_to_describe(req.user)
        })

        %InternalApi.User.UpdateResponse{
          status: google_status(:OK),
          user: req.user
        }
      else
        %InternalApi.User.UpdateResponse{status: google_status(:INVALID_ARGUMENT, "Oops")}
      end
    end

    def regenerate_token(_, _) do
      %InternalApi.User.UpdateResponse{
        status: google_status(:OK),
        user: Support.Factories.user(api_token: "token")
      }
    end

    def list_favorites(req, _) do
      favorites =
        DB.all(:favorites)
        |> Enum.filter(fn f ->
          req.user_id == f.user_id && req.organization_id == f.organization_id
        end)
        |> Enum.map(fn f ->
          %InternalApi.User.Favorite{
            user_id: f.user_id,
            organization_id: f.organization_id,
            favorite_id: f.favorite_id,
            kind: InternalApi.User.Favorite.Kind.value(f.kind)
          }
        end)

      %InternalApi.User.ListFavoritesResponse{favorites: favorites}
    end

    def create_favorite(favorite, _) do
      DB.insert(:favorites, %{
        user_id: favorite.user_id,
        organization_id: favorite.organization_id,
        favorite_id: favorite.favorite_id,
        kind: InternalApi.User.Favorite.Kind.key(favorite.kind)
      })

      favorite
    end

    def delete_favorite(favorite, _) do
      DB.delete(:favorites, fn f -> f.favorite_id == favorite.favorite_id end)

      favorite
    end

    def check_github_token(_req, _) do
      %InternalApi.User.CheckGithubTokenResponse{
        revoked: false,
        repo: true,
        public_repo: true
      }
    end

    def refresh_repository_provider(req, _) do
      user = DB.find(:users, req.user_id)

      provider =
        user.api_model.repository_providers
        |> Enum.find(fn rp -> rp.type == req.type end)

      %InternalApi.User.RefreshRepositoryProviderResponse{
        user_id: user.id,
        repository_provider: provider
      }
    end

    defp internal_status(code, message \\ "") do
      %InternalApi.ResponseStatus{
        code: InternalApi.ResponseStatus.Code.value(code),
        message: message
      }
    end

    defp google_status(code, message \\ "") do
      %Google.Rpc.Status{
        code: Google.Rpc.Code.value(code),
        message: message
      }
    end

    defp user_to_describe(user) do
      alias InternalApi.User.RepositoryScopes, as: RS

      %InternalApi.User.DescribeResponse{
        status: internal_status(:OK),
        user_id: user.id,
        name: user.name,
        email: user.email,
        avatar_url: user.avatar_url,
        company: user.company,
        repository_scopes: %RS{
          github: %RS.RepositoryScope{
            scope: RS.RepositoryScope.Scope.value(:PUBLIC),
            login: user.github_login,
            uid: user.github_uid
          },
          bitbucket: %RS.RepositoryScope{
            scope: RS.RepositoryScope.Scope.value(:NONE),
            login: "",
            uid: ""
          }
        }
      }
    end

    def describe_to_user(user) do
      %InternalApi.User.User{
        id: user.user_id,
        avatar_url: user.avatar_url,
        github_uid: user.repository_scopes.github.uid,
        name: user.name,
        github_login: user.repository_scopes.github.login,
        company: user.company,
        email: user.email,
        blocked_at: nil
      }
    end
  end
end
