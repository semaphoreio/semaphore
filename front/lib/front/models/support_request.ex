defmodule Front.Models.SupportRequest do
  use Ecto.Schema
  import Ecto.Changeset
  require Logger

  alias Front.Clients.Support

  embedded_schema do
    field(:email, :string)

    field(:topic, :string)
    field(:subject, :string)
    field(:body, :string)
    field(:provided_link, :string)
    field(:tags, {:array, :string})

    field(:file_name, :string)
    field(:file_type, :string)
    field(:file_data, :string)
    field(:file_size, :integer)
    field(:attachment, :string)
  end

  @optional_fields [:provided_link, :email, :file_name, :file_type, :file_data, :file_size, :tags]
  @image_size_limit 5_000_000

  def changeset(params \\ %{}) do
    %__MODULE__{}
    |> cast(params, [:topic, :subject, :body] ++ @optional_fields)
    |> validate_required(:topic, message: "Select a topic first.")
    |> validate_required([:subject, :body], message: "Required. Cannot be empty.")
    |> set_link_if_missing
    |> adjust_tags(params)
    |> validate_attachment
  end

  def create(input) do
    changeset = changeset(input)

    if changeset.valid? do
      with {:ok, response} <- Support.submit_request(changeset.changes) do
        {:ok, response}
      else
        {:error, "failed-to-submit"} ->
          {:error, "failed-to-submit", changeset}
      end
    else
      {:error, changeset}
    end
  end

  @spec set_link_if_missing(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def set_link_if_missing(changeset) do
    link = get_field(changeset, :provided_link)

    if is_nil(link) do
      put_change(changeset, :provided_link, "N/A")
    else
      changeset
    end
  end

  # By project design, we want to add the following tags to every submitted request
  # - 2.0-support
  # - plan type (defined with the billing proto)
  # - segment (iron, silver, gold) for paid plans
  @spec adjust_tags(Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  defp adjust_tags(changeset, params) do
    with plan <- Map.get(params, :plan),
         segment <- Map.get(params, :segment) do
      tags =
        get_field(changeset, :tags)
        |> add_semaphore_version_tag
        |> add_plan_defined_tag(plan)
        |> add_segment_tag(segment)

      put_change(changeset, :tags, tags)
    end
  end

  @spec validate_attachment(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  defp validate_attachment(changeset) do
    size = get_field(changeset, :file_size)

    if size > @image_size_limit do
      add_error(changeset, :attachment, "Attachment is too large.")
    else
      changeset
    end
  end

  defp add_plan_defined_tag(tags, :error) do
    ["failed-to-set-plan" | tags]
  end

  defp add_plan_defined_tag(tags, plan) do
    [plan | tags]
  end

  defp add_semaphore_version_tag(tags) do
    ["2.0-support" | tags]
  end

  defp add_segment_tag(tags, nil), do: tags

  defp add_segment_tag(tags, segment) do
    [segment | tags]
  end
end
