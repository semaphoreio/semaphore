defmodule Guard.Id.OAuthErrorCode do
  @moduledoc """
  Maps OAuth callback failure reasons to bounded error codes emitted in the
  callback redirect URL.

  The front-end maps these codes to user-facing text, so the set must stay
  small and stable. Free-form messages must not be passed through the URL —
  attacker-controlled query strings would otherwise be reflected as styled
  alerts on the redirect target.

  ## Canonical codes

  Every code returned by `from_reason/1` or emitted directly by the OAuth /
  OIDC callback handlers must appear in `@codes`. The front-end
  `FrontWeb.AccountController` (and any other consumer) is expected to have a
  non-generic copy for each value except `"generic"`. A coverage test in
  `front/test/front_web/controllers/account_controller_test.exs` enforces
  this — if you add a new code here, add the matching mapping there.
  """

  @codes ~w(invalid_uid missing_name missing_login auth_failed login_not_allowed generic)

  @type code ::
          String.t()

  @spec codes() :: [code()]
  def codes, do: @codes

  @spec from_reason(term()) :: code()
  def from_reason(:invalid_data), do: "invalid_uid"
  def from_reason(%Ecto.Changeset{} = changeset), do: from_changeset(changeset)
  def from_reason(_other), do: "generic"

  defp from_changeset(changeset) do
    errors = Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)

    cond do
      blank_error?(errors[:name]) -> "missing_name"
      blank_error?(errors[:login]) -> "missing_login"
      true -> "generic"
    end
  end

  defp blank_error?(errors) when is_list(errors),
    do: Enum.any?(errors, &(&1 == "can't be blank"))

  defp blank_error?(_), do: false
end
