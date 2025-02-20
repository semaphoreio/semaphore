defmodule Scouter.Repo do
  use Ecto.Repo,
    otp_app: :scouter,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Resolves the result of a changeset operation.
  """
  @spec resolve(any()) :: {:ok, any()} | {:error, String.t()}
  def resolve(value) do
    value
    |> case do
      {:ok, contact} ->
        {:ok, contact}

      {:error, changeset} ->
        errors =
          changeset
          |> format_errors()
          |> Enum.join(", ")

        {:error, errors}
    end
  end

  @spec format_errors(Ecto.Changeset.t()) :: [String.t()]
  defp format_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {key, {message, _opts}} ->
      "#{key}: #{message}"
    end)
  end
end
