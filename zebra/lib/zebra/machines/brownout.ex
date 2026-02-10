defmodule Zebra.Machines.Brownout do
  @moduledoc """
  This module is responsible for checking if a machine type is in brownout phase for a given organization.
  """

  alias Zebra.Machines.BrownoutSchedule

  @type brownout_schedule :: %{
          from: DateTime.t(),
          to: DateTime.t(),
          os_images: [String.t()]
        }

  @type brownout_schedules :: [brownout_schedule]

  @doc """
  Returns the combined brownout schedules for all OS images.
  """
  @spec schedules() :: brownout_schedules()
  def schedules do
    BrownoutSchedule.macosxcode14() ++ BrownoutSchedule.ubuntu2004()
  end

  @doc """
  Checks if machine used by organization is in brownout phase using the default schedules.
  """
  @spec os_image_in_brownout?(Datetime.t(), String.t(), String.t()) :: boolean()
  def os_image_in_brownout?(datetime, organization_id, machine_os_image) do
    os_image_in_brownout?(schedules(), datetime, organization_id, machine_os_image)
  end

  @doc """
  Checks if machine used by organization is in brownout phase.
  """
  @spec os_image_in_brownout?(brownout_schedules(), Datetime.t(), String.t(), String.t()) ::
          boolean()
  def os_image_in_brownout?(schedules, datetime, organization_id, machine_os_image) do
    apply_brownout_to_organization?(organization_id) &&
      os_image_in_scheduled_brownout?(schedules, datetime, machine_os_image)
  end

  @doc """
  Creates a brownout schedule. Use this function to create a brownout schedule in app configuration.
  """
  @spec schedule(Datetime.t(), Datetime.t(), [String.t()]) :: brownout_schedule()
  def schedule(from, to, os_images) do
    %{
      from: from,
      to: to,
      os_images: os_images
    }
  end

  @spec os_image_in_scheduled_brownout?(brownout_schedules(), DateTime.t(), String.t()) ::
          boolean()
  defp os_image_in_scheduled_brownout?(schedules, datetime, machine_os_image) do
    schedules
    |> Enum.any?(fn brownout ->
      Timex.between?(datetime, brownout[:from], brownout[:to], inclusive: true) &&
        Enum.member?(brownout[:os_images], machine_os_image)
    end)
  end

  @spec apply_brownout_to_organization?(String.t()) :: boolean()
  defp apply_brownout_to_organization?(organization_id) do
    not FeatureProvider.feature_enabled?(:exclude_from_brownouts, param: organization_id)
  end
end
