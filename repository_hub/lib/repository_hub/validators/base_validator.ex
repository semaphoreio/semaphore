defmodule RepositoryHub.BaseValidator do
  require Logger
  alias RepositoryHub.Validator
  alias RepositoryHub.Toolkit
  import Toolkit

  import Validator, only: [validate: 2]

  def select(:identity) do
    fn
      value, [] ->
        value

      _value, arg ->
        arg
    end
  end

  def select(:inspect) do
    fn value, opts ->
      label = Keyword.get(opts, :label, "inspect")

      value
      # credo:disable-for-next-line
      |> IO.inspect(label: label)
    end
  end

  # credo:disable-for-next-line
  def select(:chain) do
    fn value, validators ->
      last_item =
        validators
        |> case do
          validators when length(validators) > 1 ->
            validators
            |> List.last()
            |> case do
              {:error_message, _} = err -> err
              _ -> nil
            end

          _ ->
            nil
        end

      validators =
        last_item
        |> case do
          {:error_message, _} ->
            validators |> pop_last

          _ ->
            validators
        end

      validators
      |> Validator.compile()
      |> Enum.reduce_while(value, fn validator, value ->
        validator.(value)
        |> case do
          {:error, _} = error -> {:halt, error}
          {:ok, value} -> {:cont, value}
          value -> {:cont, value}
        end
      end)
      |> unwrap_error(fn error_message ->
        last_item
        |> case do
          {:error_message, error_message} when is_bitstring(error_message) ->
            error(error_message)

          {:error_message, error_callback} when is_function(error_callback, 1) ->
            error_callback.(error_message) |> error()

          {:error_message, error_callback} when is_function(error_callback, 2) ->
            error_callback.(error_message, value) |> error()

          nil ->
            error(error_message)
        end
      end)
      |> unwrap(fn value ->
        value
      end)
    end
  end

  def select(:from!) do
    fn
      value, keys when is_list(keys) ->
        select(:is_map).(value, [])
        |> unwrap(fn value ->
          keys
          |> Enum.reduce(value, fn key, value ->
            select(:from!).(value, key)
          end)
        end)

      value, key ->
        select(:is_map).(value, [])
        |> unwrap(fn value ->
          Map.has_key?(value, key)
          |> case do
            true -> Map.get(value, key)
            _ -> error("#{inspect(key)} is not a key in #{inspect(value)}")
          end
        end)
    end
  end

  def select(:is_map) do
    fn value, _opts ->
      value
      |> is_map
      |> case do
        true -> value
        _ -> error("is not a map")
      end
    end
  end

  def select(:any) do
    fn value, validators ->
      validation_results =
        validators
        |> Enum.map(&RepositoryHub.Validator.validate(value, [&1]))

      validation_results
      |> Enum.any?(fn
        {:error, _} -> false
        _ -> true
      end)
      |> case do
        true -> value
        _ -> Validator.resolve(validation_results, value)
      end
    end
  end

  def select(:all) do
    fn value, validators ->
      validation_results =
        validators
        |> Enum.map(&RepositoryHub.Validator.validate(value, [&1]))

      validation_results
      |> Enum.any?(fn
        {:error, _} -> true
        _ -> false
      end)
      |> case do
        false -> value
        _ -> Validator.resolve(validation_results, value)
      end
    end
  end

  def select(:take!) do
    fn value, validators ->
      validated_values =
        validators
        |> Validator.compile()
        |> Enum.map(fn validator ->
          validator.(value)
        end)

      validated_values
      |> Enum.any?(fn
        {:error, _} -> true
        _ -> false
      end)
      |> case do
        true ->
          Validator.resolve(validated_values, value)

        _ ->
          validated_values
      end
    end
  end

  def select(:check) do
    fn value, callback ->
      try do
        if callback.(value) == true do
          value
        else
          error("did not pass the check")
        end
      rescue
        e ->
          e
          |> log(level: :error)

          error("catastrophically did not pass the check")
      end
    end
  end

  def select(:length) do
    fn value, _opts ->
      cond do
        is_list(value) -> length(value)
        is_bitstring(value) -> String.length(value)
        true -> error("doesn't have length")
      end
    end
  end

  def select(:eq) do
    fn value, arg ->
      (value == arg)
      |> case do
        true -> value
        _ -> error("is not equal to #{inspect(arg)}")
      end
    end
  end

  def select(:neq) do
    fn value, arg ->
      select(:eq).(value, arg)
      |> case do
        {:error, _} -> value
        _ -> error("is equal to #{inspect(arg)}")
      end
    end
  end

  def select(:gt) do
    fn value, arg ->
      (value > arg)
      |> case do
        true -> value
        _ -> error("is not greater than #{inspect(arg)}")
      end
    end
  end

  def select(:gte) do
    fn value, arg ->
      (value >= arg)
      |> case do
        true -> value
        _ -> error("is not greater than or equal to #{inspect(arg)}")
      end
    end
  end

  def select(:lt) do
    fn value, arg ->
      (value < arg)
      |> case do
        true -> value
        _ -> error("is not lesser than #{inspect(arg)}")
      end
    end
  end

  def select(:lte) do
    fn value, arg ->
      (value <= arg)
      |> case do
        true -> value
        _ -> error("is not greater than or equal to #{inspect(arg)}")
      end
    end
  end

  def select(:is_not_empty) do
    fn value, opts ->
      select(:is_empty).(value, opts)
      |> case do
        {:error, _} -> value
        _ -> error("is empty")
      end
    end
  end

  def select(:is_empty) do
    fn value, opts ->
      empty_values = Keyword.get(opts, :empty_values, [nil, false, 0, "", [], {}, %{}])

      (value in empty_values)
      |> case do
        true -> value
        _ -> error("is not empty")
      end
    end
  end

  def select(:is_integer) do
    fn value, _opts ->
      Ecto.Type.cast(:integer, value)
      |> unwrap_error(fn _ ->
        error("is not an integer")
      end)
      |> unwrap(fn value ->
        value
      end)
    end
  end

  def select(:is_string) do
    fn value, _opts ->
      Ecto.Type.cast(:string, value)
      |> unwrap_error(fn _ ->
        error("is not a string")
      end)
      |> unwrap(fn value ->
        value
      end)
    end
  end

  def select(:is_uuid) do
    fn value, _opts ->
      Ecto.UUID.cast(value)
      |> unwrap_error(fn _ ->
        error("is not an uuid")
      end)
      |> unwrap(fn value ->
        value
      end)
    end
  end

  def select(:is_sha) do
    fn value, _ ->
      value
      |> Integer.parse(16)
      |> case do
        :error ->
          error("doesn't look like a sha")

        {_, remainder} when remainder != "" ->
          error("doesn't look like a sha")

        {parsed_value, _} ->
          if parsed_value >= 0 do
            value
          else
            error("doesn't look like a sha")
          end
      end
    end
  end

  def select(:is_github_url) do
    fn value, _ ->
      value
      |> validate(all: [:is_string, :is_not_empty])
      |> unwrap(&RepositoryHub.Model.GitRepository.new/1)
      |> unwrap(fn git_repository ->
        if git_repository.host == "github.com" do
          value
        else
          error("doesn't look like a github url")
        end
      end)
    end
  end

  def select(:is_bitbucket_url) do
    fn value, _ ->
      value
      |> validate(all: [:is_string, :is_not_empty])
      |> unwrap(&RepositoryHub.Model.GitRepository.new/1)
      |> unwrap(fn git_repository ->
        if git_repository.host == "bitbucket.org" do
          value
        else
          error("doesn't look like a bitbucket url")
        end
      end)
    end
  end

  def select(:is_gitlab_url) do
    fn value, _ ->
      value
      |> validate(all: [:is_string, :is_not_empty])
      |> unwrap(&RepositoryHub.Model.GitRepository.new/1)
      |> unwrap(fn git_repository ->
        if git_repository.host == "gitlab.com" do
          value
        else
          error("doesn't look like a gitlab url")
        end
      end)
    end
  end

  def select(:is_url) do
    fn value, _ ->
      value
      |> validate(all: [:is_string, :is_not_empty])
      |> unwrap(fn url ->
        url
        |> URI.new()
        |> case do
          {:error, message} -> error("is not a url: #{message}")
          _ -> value
        end
      end)
    end
  end

  def select(:is_file_path) do
    fn value, _ ->
      value
      |> validate(all: [:is_string, :is_not_empty])
      |> unwrap(fn _ ->
        value
      end)
    end
  end

  def select(:is_integration_type) do
    fn value, _ -> validate_integration_type(value, [:GITHUB_APP, :GITHUB_OAUTH_TOKEN, :BITBUCKET, :GIT, :GITLAB]) end
  end

  def select(:is_github_integration_type) do
    fn value, _ -> validate_integration_type(value, [:GITHUB_APP, :GITHUB_OAUTH_TOKEN]) end
  end

  def select(:is_git_integration_type) do
    fn value, _ -> validate_integration_type(value, [:GIT]) end
  end

  def select(:is_bitbucket_integration_type) do
    fn value, _ -> validate_integration_type(value, [:BITBUCKET]) end
  end

  def select(:is_gitlab_integration_type) do
    fn value, _ -> validate_integration_type(value, [:GITLAB]) end
  end

  def select(:error), do: select(:identity)

  def select(validator), do: raise("unknown validator #{inspect(validator)}")

  defp validate_integration_type(value, allowed_types) do
    value
    |> validate(
      chain: [
        any: Enum.flat_map(allowed_types, &[eq: &1]),
        error_message: "is not a valid git provider"
      ]
    )
    |> unwrap(fn _ -> value end)
  end

  defp pop_last(list) when is_list(list) do
    list |> Enum.reverse() |> tl() |> Enum.reverse()
  end
end
