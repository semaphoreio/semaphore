defmodule Support.Stubs.User do
  alias Support.Stubs.{DB, Time, UUID}

  def default_user_id, do: "78114608-be8a-465a-b9cd-81970fb802c5"

  def init do
    DB.add_table(:users, [:id, :name, :api_model])
    DB.add_table(:favorites, [:user_id, :organization_id, :favorite_id, :kind])

    __MODULE__.Grpc.init()
  end

  def switch_params(user, params) do
    new_user = params |> Keyword.merge(id: user.id) |> build()

    DB.update(:users, %{
      id: user.id,
      name: new_user.user.name,
      api_model: new_user
    })
  end

  def default do
    DB.find(:users, default_user_id())
  end

  def create_default(params \\ []) do
    defaults = [
      id: default_user_id(),
      github_repositry_scope: "private"
    ]

    defaults |> Keyword.merge(params) |> create()
  end

  def create(params \\ []) do
    user = build(params)

    DB.insert(:subjects, %{
      id: user.user.id,
      type: "user",
      name: user.user.name
    })

    DB.insert(:users, %{
      id: user.user_id,
      name: user.user.name,
      api_model: user
    })

    DB.find(:users, user.user.id)
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
    params =
      Keyword.merge(
        [
          id: UUID.gen(),
          name: "Jane",
          email: "jane.doe@example.com",
          company: "RenderedText"
        ],
        params
      )

    defaults = [
      status:
        InternalApi.ResponseStatus.new(
          code: InternalApi.ResponseStatus.Code.value(:OK),
          message: ""
        ),
      user_id: params[:id],
      name: params[:name],
      email: params[:email],
      company: params[:company],
      created_at: Time.now(),
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      github_token: "c716c3715a66612b070b6408b89c1190",
      github_scope: map_github_scope(params[:github_repositry_scope]),
      github_login: "jane-doe",
      repository_providers: [
        RepositoryProvider.new(
          type: RepositoryProvider.Type.value(:GITHUB),
          scope: map_repository_provider_scope(params[:github_repositry_scope]),
          login: "jane-doe",
          uid: "21684087"
        ),
        RepositoryProvider.new(
          type: RepositoryProvider.Type.value(:BITBUCKET),
          scope: map_repository_provider_scope(params[:bitbucket_repositry_scope]),
          login: "radwo",
          uid: "sdasd"
        )
      ],
      user: build_user(params)
    ]

    defaults |> Keyword.merge(params) |> InternalApi.User.DescribeResponse.new()
  end

  def build_user(params \\ []) do
    defaults = [
      id: UUID.gen(),
      username: "jane-doe",
      name: "Jane",
      email: "jane.doe@example.com",
      company: "RenderedText",
      avatar_url: "https://avatars3.githubusercontent.com/u/0?v=4",
      github_uid: "githubuid",
      github_login: "jane-doe",
      single_org_user: false
    ]

    defaults |> Keyword.merge(params) |> InternalApi.User.User.new()
  end

  def update_user(user, params \\ []) do
    params = %{name: params[:name], email: params[:email], company: params[:company]}
    u = Map.merge(user.user, params)

    user
    |> Map.merge(params)
    |> Map.merge(%{user: u})
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
      GrpcMock.stub(UserMock, :get_repository_token, &__MODULE__.get_repository_token/2)

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
        raise(GRPC.RPCError, status: GRPC.Status.not_found(), message: "User not found")
      end
    end

    def describe_many(req, _) do
      alias InternalApi.User.DescribeManyResponse, as: Response

      users =
        DB.all(:users)
        |> Enum.filter(fn u -> Enum.member?(req.user_ids, u.id) end)
        |> DB.extract(:api_model)
        |> Enum.map(fn u ->
          InternalApi.User.User.new(
            id: u.user_id,
            avatar_url: u.avatar_url,
            github_uid: u.github_uid,
            name: u.name,
            company: u.company,
            email: u.email
          )
        end)

      Response.new(status: internal_status(:OK), users: users)
    end

    def update(req, _) do
      user = DB.find(:users, req.user.id)

      if user do
        api_model =
          Support.Stubs.User.update_user(user.api_model,
            name: req.user.name,
            company: req.user.company,
            email: req.user.email
          )

        DB.update(:users, %{
          id: req.user.id,
          name: req.user.name,
          api_model: api_model
        })

        InternalApi.User.UpdateResponse.new(
          status: google_status(:OK),
          user: api_model.user
        )
      else
        InternalApi.User.UpdateResponse.new(status: google_status(:INVALID_ARGUMENT, "Oops"))
      end
    end

    def regenerate_token(_, _) do
      InternalApi.User.RegenerateTokenResponse.new(status: google_status(:OK), api_token: "token")
    end

    def list_favorites(req, _) do
      favorites =
        DB.all(:favorites)
        |> Enum.filter(fn f ->
          req.user_id == f.user_id && req.organization_id == f.organization_id
        end)
        |> Enum.map(fn f ->
          InternalApi.User.Favorite.new(
            user_id: f.user_id,
            organization_id: f.organization_id,
            favorite_id: f.favorite_id,
            kind: InternalApi.User.Favorite.Kind.value(f.kind)
          )
        end)

      InternalApi.User.ListFavoritesResponse.new(favorites: favorites)
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
      InternalApi.User.CheckGithubTokenResponse.new(
        revoked: false,
        repo: true,
        public_repo: true
      )
    end

    def get_repository_token(request, _) do
      if request.user_id == "invalid_response" do
        raise GRPC.RPCError, status: :invalid_argument, message: "Invalid request."
      else
        %InternalApi.User.GetRepositoryTokenResponse{
          token: "valid_token_value",
          expires_at: Google.Protobuf.Timestamp.new(seconds: 1_522_495_543)
        }
      end
    end

    def refresh_repository_provider(req, _) do
      user = DB.find(:users, req.user_id)

      provider =
        user.api_model.repository_providers
        |> Enum.find(fn rp -> rp.type == req.type end)

      InternalApi.User.RefreshRepositoryProviderResponse.new(
        user_id: user.id,
        repository_provider: provider
      )
    end

    defp internal_status(code, message \\ "") do
      InternalApi.ResponseStatus.new(
        code: InternalApi.ResponseStatus.Code.value(code),
        message: message
      )
    end

    defp google_status(code, message \\ "") do
      Google.Rpc.Status.new(
        code: Google.Rpc.Code.value(code),
        message: message
      )
    end

    def describe_to_user(user) do
      InternalApi.User.User.new(
        id: user.user_id,
        avatar_url: user.avatar_url,
        github_uid: user.repository_scopes.github.uid,
        name: user.name,
        github_login: user.repository_scopes.github.login,
        company: user.company,
        email: user.email,
        blocked_at: nil
      )
    end
  end
end
