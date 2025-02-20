defmodule Projecthub.ParamsChecker do
  def run(spec, open_source) do
    public = spec.visibility == :PUBLIC

    validate_public_status(public, open_source)
  end

  defp validate_public_status(false, true),
    do: {:error, ["Only public projects are allowed"]}

  defp validate_public_status(_, _), do: :ok
end
