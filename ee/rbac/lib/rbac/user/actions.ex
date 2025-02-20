defmodule Rbac.User.Actions do
  alias Rbac.User.SaltGenerator

  alias Rbac.Repo
  alias Rbac.FrontRepo

  require Logger

  @exchange_name "user_exchange"

  @type user_params :: Map.t()
  @type membership :: %{org_id: String.t(), role_id: String.t()}

  @spec create(user_params, membership | nil) ::
          {:ok, Repo.RbacUser.t()} | {:error, List.t()} | {:error, Atom.t()}
  def create(user_params, membership \\ nil) do
    {password, user_params} = Map.pop(user_params, :password)
    {oidc_user_id, user_params} = Map.pop(user_params, :oidc_user_id)
    name = ensure_name(user_params.name, user_params.email)
    user_params = Map.put(user_params, :name, name)

    case _create(user_params, password, oidc_user_id) do
      {:ok, user} ->
        Rbac.Events.UserCreated.publish(user.id, invited?(membership))

        {:ok, user}

      error ->
        error
    end
  end

  defp ensure_name(name, email) when is_nil(name) or name == "" do
    case String.split(email, "@") do
      [username | _] -> username
      _ -> nil
    end
  end

  defp ensure_name(name, _), do: name

  defp invited?(nil), do: false
  defp invited?(_), do: true

  defp _create(params, password, oidc_user_id) do
    FrontRepo.transaction(fn ->
      case Repo.transaction(fn ->
             with {:ok, front_user} <- create_front_user(params),
                  {:ok, user} <- create_rbac_user(front_user),
                  {:ok, oidc_user_id} <- create_oidc_user(oidc_user_id, user, password),
                  {:ok, _oidc_user} <- connect_oidc_user(oidc_user_id, user.id) do
               user
             else
               {:error, error} ->
                 Repo.rollback(error)
             end
           end) do
        {:ok, user} ->
          user

        {:error, error} ->
          FrontRepo.rollback(error)
      end
    end)
  end

  defp create_front_user(params) do
    Map.merge(params, %{
      salt: SaltGenerator.gen(),
      remember_created_at: DateTime.utc_now()
    })
    |> Rbac.Store.User.Front.create()
  end

  defp create_rbac_user(front_user) do
    case Rbac.Store.RbacUser.create(front_user.id, front_user.email, front_user.name) do
      :ok ->
        case Rbac.Store.RbacUser.fetch(front_user.id) do
          nil -> {:error, :not_user}
          user -> {:ok, user}
        end

      :error ->
        {:error, :no_user}
    end
  end

  defp create_oidc_user(nil = _oidc_user_id, user, password) do
    if Rbac.OIDC.enabled?() do
      case Rbac.OIDC.User.create_oidc_user(user, password_data: [password: password]) do
        {:ok, oidc_user_id} ->
          Logger.info(
            "User created successfully: #{inspect(user)} and connected to OIDC user: #{inspect(oidc_user_id)}"
          )

          {:ok, oidc_user_id}

        error ->
          Logger.error("Failed to create user: #{inspect(error)}")

          {:error, :no_user}
      end
    else
      {:ok, ""}
    end
  end

  defp create_oidc_user(oidc_user_id, _user, _password) do
    Logger.info("OIDC id #{inspect(oidc_user_id)} present, skipping creation of new OIDC user")
    {:ok, oidc_user_id}
  end

  defp connect_oidc_user(oidc_user_id, user_id) do
    if Rbac.OIDC.enabled?() do
      Rbac.Store.OIDCUser.connect_user(oidc_user_id, user_id)
    else
      {:ok, nil}
    end
  end

  @spec update(String.t(), user_params) ::
          {:ok, FrontRepo.User.t()} | {:error, List.t()} | {:error, Atom.t()}
  def update(user_id, user_params) do
    case Rbac.Store.User.Front.update(user_id, user_params) do
      {:ok, user} ->
        Rbac.Events.UserUpdated.publish(user.id, @exchange_name)

        {:ok, user}

      error ->
        error
    end
  end
end
