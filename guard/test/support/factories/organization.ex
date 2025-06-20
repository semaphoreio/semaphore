defmodule Support.Factories.Organization do
  def insert!(options \\ []) do
    defaults = [
      creator_id: Ecto.UUID.generate(),
      name: "Test Organization",
      username: "test-org",
      suspended: false,
      open_source: false,
      description: "Test Organization Description",
      website: "https://example.com",
      avatar_url: "https://example.com/avatar.png",
      allowed_id_providers: "api_token,oidc"
    ]

    attrs = Keyword.merge(defaults, options) |> Enum.into(%{})

    %Guard.FrontRepo.Organization{}
    |> Guard.FrontRepo.Organization.changeset(attrs)
    |> Guard.FrontRepo.insert!(returning: true)
  end

  def insert_contact!(org_id, options \\ []) do
    defaults = [
      organization_id: org_id,
      contact_type: :CONTACT_TYPE_MAIN,
      email: "contact@example.com",
      name: "John Doe",
      phone: "+1 555 000 000",
      role: "admin"
    ]

    attrs = Keyword.merge(defaults, options) |> Enum.into(%{})

    %Guard.FrontRepo.OrganizationContact{}
    |> Guard.FrontRepo.OrganizationContact.changeset(attrs)
    |> Guard.FrontRepo.insert!(returning: true)
  end

  def insert_suspension!(org_id, options \\ []) do
    defaults = [
      organization_id: org_id,
      reason: :INSUFFICIENT_FUNDS,
      origin: "billing",
      description: "Account has insufficient funds",
      deleted_at: nil
    ]

    attrs = Keyword.merge(defaults, options) |> Enum.into(%{})

    %Guard.FrontRepo.OrganizationSuspension{}
    |> Guard.FrontRepo.OrganizationSuspension.changeset(attrs)
    |> Guard.FrontRepo.insert!(returning: true)
  end
end
