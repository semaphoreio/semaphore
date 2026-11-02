defmodule FrontWeb.OAuthFlashMessage do
  @moduledoc """
  User-facing text for the outcome of a repository-provider OAuth connect.

  guard appends `status`, and on failure `code`, to whatever `redirect_path`
  started the connect, so these messages are rendered by
  `FrontWeb.Plug.OAuthFlash` rather than by any one controller.
  """

  @spec success() :: String.t()
  def success, do: "Repository account connected."

  @spec error(String.t() | nil) :: String.t()
  def error("invalid_uid"),
    do:
      "Your account did not return the required profile data (username or user ID). " <>
        "Please verify your account is fully set up and try again."

  def error("missing_name"),
    do:
      "Your profile is missing a display name. " <>
        "Please set a name in your account settings and try connecting again."

  def error("missing_login"), do: "Your profile is missing a username."

  def error("login_not_allowed"),
    do:
      "Login is not allowed when using SAML as the default authentication method. " <>
        "Please contact your administrator."

  def error("auth_failed"),
    do:
      "We couldn't authenticate. Please try again. " <>
        "If the problem persists, contact our support team."

  def error("account_taken"),
    do:
      "This account is already connected to another Semaphore user. " <>
        "A GitHub account can only be linked to one Semaphore user. " <>
        "If you believe this is an error, contact your administrator or our support team."

  def error(_code), do: generic()

  @spec generic() :: String.t()
  def generic,
    do:
      "We're sorry, but your connection attempt was unsuccessful. Please try again. " <>
        "If you continue to experience issues, please contact our support team for assistance."
end
