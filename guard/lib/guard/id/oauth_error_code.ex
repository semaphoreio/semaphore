defmodule Guard.Id.OAuthErrorCode do
  @moduledoc """
  Maps OAuth callback failure reasons to bounded error codes emitted in the
  callback redirect URL. Front-end maps codes to user-facing text.
  """

  @codes ~w(invalid_uid missing_name missing_login auth_failed login_not_allowed account_taken generic)

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
      Guard.FrontRepo.RepoHostAccount.uid_taken_error?(changeset) -> "account_taken"
      blank_error?(errors[:name]) -> "missing_name"
      blank_error?(errors[:login]) -> "missing_login"
      true -> "generic"
    end
  end

  defp blank_error?(errors) when is_list(errors),
    do: Enum.any?(errors, &(&1 == "can't be blank"))

  defp blank_error?(_), do: false
end
