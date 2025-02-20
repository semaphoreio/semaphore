defmodule Front.Zendesk do
  defmodule JWT do
    use Joken.Config

    def token_config, do: default_claims(iss: "Semaphore", aud: "Zendesk")

    def generate(user) do
      signer = Joken.Signer.create("HS256", jwt_secret())

      user_params(user)
      |> generate_and_sign!(signer)
    end

    defp jwt_secret, do: Application.get_env(:front, :zendesk_jwt_secret)

    defp user_params(user) do
      domain = Application.get_env(:front, :domain)

      %{
        "email" => user.email,
        "name" => user.name,
        "external_id" => user.id,
        "user_fields" => %{
          "github_username" => user.github_login,
          "bitbucket_uuid" => user.bitbucket_uid,
          "gitlab_login" => user.gitlab_login,
          "semaphore_user_id" => user.id,
          "insider_url" => "https://admin.#{domain}/insider/users/#{user.id}"
        }
      }
    end
  end

  def new_ticket_location, do: "#{zendesk_support_url()}/hc/en-us/requests/new"

  def my_tickets_location, do: "#{zendesk_support_url()}/hc/en-us/requests"

  def sso_location(return_to)
      when is_binary(return_to) and return_to != "",
      do: "#{zendesk_jwt_url()}/access/jwt?return_to=#{return_to}"

  def sso_location(_return_to),
    do: "#{zendesk_jwt_url()}/access/jwt"

  defp zendesk_jwt_url, do: Application.get_env(:front, :zendesk_jwt_url)
  defp zendesk_support_url, do: Application.get_env(:front, :zendesk_support_url)
end
