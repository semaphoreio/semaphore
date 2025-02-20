defmodule Guard.User.SaltGenerator do
  @moduledoc """
  Generates a new salt for the user. The salt must be unique accross
  all users, as it is able to uniquely identify a customer via the
  session cookie.

  In the context of the session cookie, the salt is saved under the
  warden.user.user.key.

  Typically, after decrypting, the content of the warden.user.user.key is
  [[<user.id>], <user.salt>]
  """

  @salt_len 22
  @default_max_tries 100

  def gen, do: gen(max_iterations: @default_max_tries)

  defp gen(max_iterations: 0), do: raise("Failed to generate a secure salt for a user")

  defp gen(max_iterations: max_iterations) do
    salt = new_secure_salt()

    if user_exists?(salt) do
      gen(max_iterations: max_iterations - 1)
    else
      salt
    end
  end

  def user_exists?(salt) do
    import Ecto.Query, only: [from: 2]

    query = from(u in Guard.FrontRepo.User, where: u.salt == ^salt)

    Guard.FrontRepo.exists?(query)
  end

  defp new_secure_salt do
    :crypto.strong_rand_bytes(@salt_len)
    |> Base.url_encode64()
    |> binary_part(0, @salt_len)
  end
end
