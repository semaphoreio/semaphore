defmodule Guard.User.UpdateMails do
  @moduledoc """
    This module contains a script that goes through all the users within a given org,
    checks if they have corporate emails, and if not, goes through secondary GitHub emails
    to see if one of those is a corporate mail. If so, the email is updated, if not, nothing happens.

    This script is not used from anywhere within the code base, and is ment to be ran manualy. For now,
    the only use-case for this script was when a organization wants to use SCIM/SAML for SSO, and emails
    in their SAML provider need to match emails on Semaphoere.
  """

  import Ecto.Query
  require Logger

  @github_api_domain "https://api.github.com/user/emails"

  @doc """
    If an organization has corporate email address that ends with important-org.org, that would be given
    as a parameter togeather with the org's semaphore id.

    The function returns a list of all updated emails. If `nil` values appear in this list, that
    means some users dont have corporate email, but the scrip wasn't able to find one. Either their GitHub API
    token is not valid, or more likely they did not connect ther GitHub account with their corporate mail.
  """
  def migrate(org_id, corporate_email_domain) do
    get_wrong_email_users(org_id, corporate_email_domain)
    |> Enum.map(fn id -> {id, get_api_token(id)} end)
    |> Enum.filter(fn {_, token} -> token != nil end)
    |> Enum.each(fn {id, token} ->
      {:ok, resp} = HTTPoison.get(@github_api_domain, [{"Authorization", "Token #{token}"}])
      {:ok, body} = resp |> Map.get(:body) |> Jason.decode()

      if is_list(body) do
        body
        |> Enum.map(fn email -> email["email"] end)
        |> update_email(id, corporate_email_domain)
      else
        Logger.error("Bad request for user #{id}: #{inspect(resp)}")
      end
    end)
  end

  def update_email(emails, user_id, corporate_email_domain) do
    new_mail = emails |> Enum.find(&(&1 =~ "@#{corporate_email_domain}"))

    if new_mail == nil do
      Logger.info("Could not find corporate email for #{user_id}")
    else
      Logger.info("Updating email for user #{user_id} to #{new_mail}")

      Guard.Repo.RbacUser
      |> where([u], u.id == ^user_id)
      |> Guard.Repo.update_all(set: [email: new_mail])

      Guard.FrontRepo.User
      |> where([u], u.id == ^user_id)
      |> Guard.FrontRepo.update_all(set: [email: new_mail])

      if Guard.OIDC.enabled?() do
        handle_oidc_sync(user_id)
      end
    end
  end

  def handle_oidc_sync(user_id) do
    user = Guard.Store.RbacUser.fetch(user_id)

    case Guard.Store.OIDCUser.fetch_by_user_id(user_id) do
      {:ok, oidc_user} ->
        case Guard.OIDC.User.update_oidc_user(oidc_user.oidc_user_id, user) do
          {:ok, oidc_user_id} ->
            Logger.info("OIDC user #{oidc_user_id} updated")

          e ->
            Logger.error("Error syncing new user with OIDC #{inspect(e)}")
        end

      {:error, :not_found} ->
        Logger.error("While updating an existing user, the same OIDC user was not found!")
    end
  end

  def get_wrong_email_users(org_id, corporate_email_domain) do
    Guard.Repo.SubjectRoleBinding
    |> join(:inner, [srb], u in Guard.Repo.RbacUser, on: srb.subject_id == u.id)
    |> where(
      [srb, u],
      srb.org_id == ^org_id and is_nil(srb.project_id) and
        not like(u.email, ^"%#{corporate_email_domain}%")
    )
    |> select([srb], srb.subject_id)
    |> Guard.Repo.all()
  end

  defp get_api_token(user_id) do
    Guard.FrontRepo.RepoHostAccount.get_github_token(user_id)
    |> case do
      {:error, reason} ->
        Logger.info("Failed to get GitHub token for user #{user_id}: #{inspect(reason)}")
        nil

      {:ok, token} ->
        token
    end
  end
end
