defmodule FeatureProvider.Machine do
  alias __MODULE__

  defstruct [
    :type,
    :platform,
    :vcpu,
    :ram,
    :disk,
    :default_os_image,
    :available_os_images,
    :quantity,
    :state
  ]

  @type state :: :enabled | :disabled | :zero_state
  @type quantity :: non_neg_integer()

  @type t :: %Machine{
          type: String.t(),
          platform: String.t(),
          vcpu: String.t(),
          ram: String.t(),
          disk: String.t(),
          default_os_image: String.t(),
          available_os_images: String.t(),
          quantity: quantity(),
          state: state()
        }

  @doc """
  Checks if the machine is in an enabled state.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `false`.

  ## Examples

        iex> enabled?(nil)
        false

        iex> enabled?(%FeatureProvider.Machine{state: :enabled})
        true

        iex> enabled?(%FeatureProvider.Machine{state: :hidden})
        false

        iex> enabled?(%FeatureProvider.Machine{state: :zero_state})
        false

        iex> enabled?(%FeatureProvider.Machine{state: :invalid_state})
        false
  """
  @spec enabled?(any() | t()) :: boolean()
  def enabled?(%Machine{} = machine), do: machine.state == :enabled
  def enabled?(_), do: false

  @doc """
  Checks if the machine is in a zero state.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `false`.

  ## Examples

        iex> zero_state?(nil)
        false

        iex> zero_state?(%FeatureProvider.Machine{state: :enabled})
        false

        iex> zero_state?(%FeatureProvider.Machine{state: :hidden})
        false

        iex> zero_state?(%FeatureProvider.Machine{state: :zero_state})
        true

        iex> zero_state?(%FeatureProvider.Machine{state: :invalid_state})
        false
  """
  @spec zero_state?(any() | t()) :: boolean()
  def zero_state?(%Machine{} = machine), do: machine.state == :zero_state
  def zero_state?(_), do: false

  @doc """
  Checks if the machine is visible.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `false`.

  ## Examples

        iex> visible?(nil)
        false

        iex> visible?(%FeatureProvider.Machine{state: :enabled})
        true

        iex> visible?(%FeatureProvider.Machine{state: :hidden})
        false

        iex> visible?(%FeatureProvider.Machine{state: :zero_state})
        true

        iex> visible?(%FeatureProvider.Machine{state: :invalid_state})
        false
  """
  @spec visible?(any() | t()) :: boolean()
  def visible?(%Machine{} = machine), do: enabled?(machine) or zero_state?(machine)
  def visible?(_), do: false

  @doc """
  Returns a quota on the machine.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `0`.

  ## Examples

        iex> quota(nil)
        0

        iex> quota(%FeatureProvider.Machine{quantity: 0})
        0

        iex> quota(%FeatureProvider.Machine{quantity: 1})
        1

        iex> quota(%FeatureProvider.Machine{quantity: 5})
        5

        iex> quota(%FeatureProvider.Machine{quantity: 100})
        100
  """
  @spec quota(any() | t()) :: quantity()
  def quota(%Machine{} = machine), do: machine.quantity
  def quota(_), do: 0

  @doc """
  Checks if the machine is a linux machine.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `false`.

  ## Examples

        iex> linux?(nil)
        false

        iex> linux?(%FeatureProvider.Machine{platform: "linux"})
        true

        iex> linux?(%FeatureProvider.Machine{platform: "mac"})
        false

        iex> linux?(%FeatureProvider.Machine{platform: "windows"})
        false
  """
  @spec linux?(any() | t()) :: boolean()
  def linux?(%Machine{} = machine), do: machine.platform == "linux"
  def linux?(_), do: false

  @doc """
  Checks if the machine is a macos machine.

  If `machine` is not a `%FeatureProvider.Machine{}` struct, it returns `false`.

  ## Examples

        iex> mac?(nil)
        false

        iex> mac?(%FeatureProvider.Machine{platform: "linux"})
        false

        iex> mac?(%FeatureProvider.Machine{platform: "mac"})
        true

        iex> mac?(%FeatureProvider.Machine{platform: "windows"})
        false
  """
  @spec mac?(any() | t()) :: boolean()
  def mac?(%Machine{} = machine), do: machine.platform == "mac"
  def mac?(_), do: false
end
