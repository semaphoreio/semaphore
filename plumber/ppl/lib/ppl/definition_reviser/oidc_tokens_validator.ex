defmodule Ppl.DefinitionReviser.OIDCTokensValidator do
  @moduledoc """
  Validates the `oidc_tokens` block on jobs.

  Schema-level validation (env var name regex, `aud` shape) happens earlier in
  the definition validator. This module enforces semantic rules that JSON
  Schema cannot express.

  Currently it rejects the reserved key `SEMAPHORE_OIDC_TOKEN`: that name is
  used for the auto-injected default OIDC token, so allowing it as a custom
  token name would clobber the job's environment variable.
  """

  alias Util.ToTuple

  @reserved_token_names ~w(SEMAPHORE_OIDC_TOKEN)

  @type definition :: map()
  @type error :: {:error, {:malformed, String.t()}}

  @spec validate(definition) :: {:ok, definition} | error
  def validate(definition) do
    with {:ok, definition} <- do_validate(definition, "blocks"),
         {:ok, definition} <- do_validate(definition, "after_pipeline") do
      ToTuple.ok(definition)
    else
      {:error, _} = error -> error
    end
  end

  defp do_validate(definition, "blocks") do
    with {:ok, blocks} <- Map.fetch(definition, "blocks"),
         :ok <- validate_blocks(blocks) do
      {:ok, definition}
    end
  end

  defp do_validate(definition, "after_pipeline") do
    case Map.get(definition, "after_pipeline") do
      nil ->
        {:ok, definition}

      blocks ->
        blocks = Enum.map(blocks, &Map.put(&1, "name", "after_pipeline"))

        case validate_blocks(blocks) do
          :ok -> {:ok, definition}
          {:error, _} = error -> error
        end
    end
  end

  defp validate_blocks(blocks) do
    Enum.reduce_while(blocks, :ok, fn block, :ok ->
      case validate_block(block) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_block(block) do
    block_name = Map.get(block, "name")
    jobs = block |> get_in(["build", "jobs"]) |> List.wrap()

    Enum.reduce_while(jobs, :ok, fn job, :ok ->
      case validate_job(block_name, job) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp validate_job(block_name, job) do
    case Map.get(job, "oidc_tokens") do
      tokens when is_map(tokens) ->
        check_reserved_names(block_name, Map.get(job, "name"), tokens)

      _ ->
        :ok
    end
  end

  defp check_reserved_names(block_name, job_name, tokens) do
    case Enum.find(@reserved_token_names, &Map.has_key?(tokens, &1)) do
      nil ->
        :ok

      reserved ->
        message = reserved_name_error(block_name, job_name, reserved)
        {:error, {:malformed, message}}
    end
  end

  defp reserved_name_error(block_name, job_name, name) do
    "Token name '#{name}' is reserved and cannot be used as a custom oidc_tokens key " <>
      "(block '#{block_name}', job '#{job_name}'). Use a different environment variable name."
  end
end
