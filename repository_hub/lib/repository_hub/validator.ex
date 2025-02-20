defmodule RepositoryHub.Validator do
  alias RepositoryHub.Toolkit
  import Toolkit

  @type global_validator_name :: atom()
  @type validator_argument :: list()

  @type validator ::
          global_validator_name
          | {global_validator_name, validator_argument()}
          | (value_to_validate :: any() -> validator_result())
          | (value_to_validate :: any(), validator_argument() -> validator_result())

  @type validator_callback :: (value :: any() -> validator_result())
  @type validator_result() :: Toolkit.ok_tuple() | Toolkit.error_tuple(String.t())

  @doc """
  Validates the value with a list of validators.

    ## Examples

      iex> validate(1, [eq: 1])
      {:ok, 1}
      iex> validate(1, fn _ -> {:error, "I've failed"} end)
      {:error, "I've failed"}

      iex> validate(1, [fn _ -> {:error, "I've failed"} end, fn _ -> {:error, "I've failed too"} end, fn _ -> {:error, "So did I"} end])
      {:error, "I've failed, I've failed too, So did I"}

      iex> validate(1, [fn _ -> {:error, "I've failed"} end, fn _ -> {:error, "I've failed too"} end, fn _ -> {:error, "So did I"} end])
      {:error, "I've failed, I've failed too, So did I"}

  """
  @spec validate(any, [validator()]) :: validator_result()
  def validate(value_to_validate, validators) do
    validators
    |> compile()
    |> Enum.map(fn validate ->
      validate.(value_to_validate)
    end)
    |> resolve(value_to_validate)
  end

  @doc """
  Compiles validators to a list of functions accepting value to validate as an argument.

   ## Examples

      iex> validators = [:identity, {:eq, 2}, fn _ -> {:ok, "I'm fine"} end, {fn _, name -> {:error, "\#{name} - I'm not fine"} end, "Joe"}]
      ...> compiled_validators = compile(validators)
      ...> Enum.map(compiled_validators, & &1.(2))
      [2, 2, {:ok, "I'm fine"}, {:error, "Joe - I'm not fine"}]
  """
  @spec compile(validators :: [validator]) :: [validator_callback]
  def compile(validators) do
    validators
    |> to_list
    |> ensure_validator_arguments()
    |> Enum.map(&normalize/1)
  end

  @doc """
  Resolves the validation result.
  If every validation resolves to ok tuple, wrapped value will be returned.
  In case any validations resolves to error tuple, error messages from validations will be
  concatenated and returned as error message.
  """
  @spec resolve(results :: [validator_result()], value :: term()) ::
          Toolkit.ok_tuple(value :: term()) | Toolkit.error_tuple(String.t())
  def resolve(results, value) do
    results
    |> Enum.filter(fn
      {:error, _} -> true
      _ -> false
    end)
    |> case do
      errors when errors == [] ->
        wrap(value)

      errors ->
        errors
        |> Enum.map_join(", ", &elem(&1, 1))
        |> error()
    end
    |> case do
      {:ok, _} -> wrap(value)
      error -> error
    end
  end

  @doc """
  This function makes sure that all validators have an argument.
  When argument is a list - this function is recursively called on each element.
  If not `[]` is used as a default

  ## Examples
    iex> ensure_validator_arguments({:a, []})
    {:a, []}

    iex> ensure_validator_arguments(:a)
    {:a, []}

    iex> ensure_validator_arguments([:a, :b, :c])
    [{:a, []}, {:b, []}, {:c, []}]

    iex> ensure_validator_arguments([:a, :b, c: 2, d: 3])
    [{:a, []}, {:b, []}, {:c, 2}, {:d, 3}]

    iex> ensure_validator_arguments([:a, [:b, [:c]]])
    [{:a, []}, [{:b, []}, [{:c, []}]]]

  """
  def ensure_validator_arguments(validator) do
    validator
    |> then(fn
      {validator, validator_opts} ->
        {validator, validator_opts}

      validators when is_list(validators) ->
        validators
        |> Enum.map(&ensure_validator_arguments/1)

      validator ->
        {validator, []}
    end)
  end

  @doc """
  Normalizes a validator tuple to a function that accepts one value - the value to validate.
  Validations can run only on ok_tuples and plain values. Error tuples as values **will not** trigger validations.

  ## Examples
    iex> is_function(normalize({:some_global_validator, []}), 1)
    true

    iex> is_function(normalize({& &1, []}), 1)
    true

    iex> is_function(normalize({& &1 + &2, []}), 1)
    true

    iex> normalize(:a)
    ** (RuntimeError) only atoms, one-argument and two-argument functions callbacks can be validators, got :a
  """
  def normalize(validator_tuple) do
    validator_tuple
    |> case do
      {validator_name, validator_argument} when is_atom(validator_name) ->
        fn value ->
          value
          |> unwrap(fn value ->
            RepositoryHub.BaseValidator.select(validator_name).(
              value,
              validator_argument
            )
          end)
        end

      {validator_func, validator_argument} when is_function(validator_func, 2) ->
        fn value ->
          value
          |> unwrap(fn value ->
            validator_func.(value, validator_argument)
          end)
        end

      {validator_func, _validator_argument} when is_function(validator_func, 1) ->
        validator_func

      invalid ->
        raise(
          "only atoms, one-argument and two-argument functions callbacks can be validators, got #{inspect(invalid)}"
        )
    end
  end

  defp to_list(value) do
    value
    |> is_list()
    |> case do
      true -> value
      _ -> [value]
    end
  end
end
