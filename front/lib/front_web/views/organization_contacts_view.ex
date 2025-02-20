defmodule FrontWeb.OrganizationContactsView do
  use FrontWeb, :view

  def extract_contact_type(changeset) do
    Ecto.Changeset.get_field(changeset, :contact_type)
  end

  def extract_contact_type_description(changeset) do
    case extract_contact_type(changeset) do
      "Main" ->
        "This contact will be our primary point of communication regarding any matters concerning your Semaphore organization."

      "Finances" ->
        "This contact will be used specifically for any billing-related topics pertaining to your Semaphore organization."

      "Security" ->
        "This contact will be utilized for any discussions related to the security of your Semaphore organization."

      _ ->
        ""
    end
  end
end
