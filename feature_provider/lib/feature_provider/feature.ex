defmodule FeatureProvider.Feature do
  alias __MODULE__

  defstruct [
    :name,
    :type,
    :description,
    :quantity,
    :state
  ]

  @type state :: :enabled | :disabled | :zero_state
  @type quantity :: non_neg_integer()

  @type t :: %Feature{
          name: String.t(),
          type: String.t(),
          description: String.t(),
          quantity: quantity(),
          state: state()
        }

  @doc """
  Checks if the feature is enabled.

  If `feature` is not a `%FeatureProvider.Feature{}` struct, it returns `false`.

  ## Examples

        iex> enabled?(nil)
        false

        iex> enabled?(%FeatureProvider.Feature{state: :enabled})
        true

        iex> enabled?(%FeatureProvider.Feature{state: :hidden})
        false

        iex> enabled?(%FeatureProvider.Feature{state: :zero_state})
        false

        iex> enabled?(%FeatureProvider.Feature{state: :invalid_state})
        false
  """
  @spec enabled?(any() | t()) :: boolean
  def enabled?(%Feature{} = feature), do: feature.state == :enabled
  def enabled?(_), do: false

  @doc """
  Checks if the feature is in a zero state.

  If `feature` is not a `%FeatureProvider.Feature{}` struct, it returns `false`.

  ## Examples

        iex> zero_state?(nil)
        false

        iex> zero_state?(%FeatureProvider.Feature{state: :enabled})
        false

        iex> zero_state?(%FeatureProvider.Feature{state: :hidden})
        false

        iex> zero_state?(%FeatureProvider.Feature{state: :zero_state})
        true

        iex> zero_state?(%FeatureProvider.Feature{state: :invalid_state})
        false
  """
  @spec zero_state?(any() | t()) :: boolean
  def zero_state?(%Feature{} = feature), do: feature.state == :zero_state
  def zero_state?(_), do: false

  @doc """
  Checks if the feature is visible.

  If `feature` is not a `%FeatureProvider.Feature{}` struct, it returns `false`.

  ## Examples

        iex> visible?(nil)
        false

        iex> visible?(%FeatureProvider.Feature{state: :enabled})
        true

        iex> visible?(%FeatureProvider.Feature{state: :hidden})
        false

        iex> visible?(%FeatureProvider.Feature{state: :zero_state})
        true

        iex> visible?(%FeatureProvider.Feature{state: :invalid_state})
        false
  """
  @spec visible?(any() | t()) :: boolean()
  def visible?(%Feature{} = feature), do: enabled?(feature) or zero_state?(feature)
  def visible?(_), do: false

  @doc """
  Returns a quota on the feature.

  If `feature` is not a `%FeatureProvider.Feature{}` struct, it returns `false`.

  ## Examples

        iex> quota(nil)
        0

        iex> quota(%FeatureProvider.Feature{quantity: 0})
        0

        iex> quota(%FeatureProvider.Feature{quantity: 1})
        1

        iex> quota(%FeatureProvider.Feature{quantity: 5})
        5

        iex> quota(%FeatureProvider.Feature{quantity: 100})
        100
  """
  @spec quota(any() | t()) :: quantity()
  def quota(%Feature{} = feature), do: feature.quantity
  def quota(_), do: 0
end
