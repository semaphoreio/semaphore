module RepoHost::Github::Responses::Marketplace
  def self.marketplace_purchases
    [
      {
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-09-01T00:00:00+02:00",
        "unit_count" => nil,
        "account" => {
          "login" => "github",
          "id" => 4,
          "url" => "https://api.github.com/orgs/github",
          "email" => nil,
          "organization_billing_email" => "billing@github.com",
          "type" => "Organization"
        },
        "plan" => {
          "url" => "https://api.github.com/marketplace_listing/plans/9",
          "accounts_url" => "https://api.github.com/marketplace_listing/plans/9/accounts",
          "id" => 9,
          "name" => "Bootstrap",
          "description" => "A professional-grade CI solution",
          "monthly_price_in_cents" => 1099,
          "yearly_price_in_cents" => 11870,
          "price_model" => "flat-rate",
          "unit_name" => nil,
          "bullets" => [
            "This is the first bullet of the Pro plan",
            "This is the second bullet of the Pro plan"
          ]
        }
      },
      {
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-09-01T00:00:00+02:00",
        "unit_count" => nil,
        "account" => {
          "login" => "test",
          "id" => 2,
          "url" => "https://api.github.com/users/test",
          "email" => "test@example.com",
          "type" => "User"
        },
        "plan" => {
          "url" => "https://api.github.com/marketplace_listing/plans/7",
          "accounts_url" => "https://api.github.com/marketplace_listing/plans/7/accounts",
          "id" => 7,
          "name" => "Open Source",
          "description" => "A free CI solution",
          "monthly_price_in_cents" => 0,
          "yearly_price_in_cents" => 0,
          "price_model" => "free",
          "unit_name" => nil,
          "bullets" => [
            "This is the first bullet of the free plan",
            "This is the second bullet of the free plan"
          ]
        }
      }
    ]
  end

  def self.plans
    [
      {
        "url" => "https://api.github.com/marketplace_listing/plans/7",
        "accounts_url" => "https://api.github.com/marketplace_listing/plans/7/accounts",
        "id" => 7,
        "name" => "Bootstrap",
        "description" => "A professional-grade CI solution",
        "monthly_price_in_cents" => 1099,
        "yearly_price_in_cents" => 11870,
        "price_model" => "flat-rate",
        "unit_name" => nil,
        "bullets" => [
          "This is the first bullet of the plan",
          "This is the second bullet of the plan"
        ]
      },
      {
        "url" => "https://api.github.com/marketplace_listing/plans/8",
        "accounts_url" => "https://api.github.com/marketplace_listing/plans/8/accounts",
        "id" => 8,
        "name" => "Startup",
        "description" => "A professional-grade CI solution",
        "monthly_price_in_cents" => 1099,
        "yearly_price_in_cents" => 11870,
        "price_model" => "flat-rate",
        "unit_name" => nil,
        "bullets" => [
          "This is the first bullet of the plan",
          "This is the second bullet of the plan"
        ]
      },
      {
        "url" => "https://api.github.com/marketplace_listing/plans/9",
        "accounts_url" => "https://api.github.com/marketplace_listing/plans/9/accounts",
        "id" => 9,
        "name" => "Growth",
        "description" => "A professional-grade CI solution",
        "monthly_price_in_cents" => 1099,
        "yearly_price_in_cents" => 11870,
        "price_model" => "flat-rate",
        "unit_name" => nil,
        "bullets" => [
          "This is the first bullet of the plan",
          "This is the second bullet of the plan"
        ]
      }
    ]
  end

  def self.accounts(account_id = 4, account_type = "Organization", plan_name = "Bootstrap")
    [
      {
        "url" => "https://api.github.com/marketplace_listing/accounts/4",
        "type" => account_type,
        "id" => account_id,
        "login" => "GitHub",
        "marketplace_purchase" => {
          "billing_cycle" => "monthly",
          "next_billing_date" => "2017-05-01T00:00:00Z",
          "unit_count" => nil,
          "plan" => {
            "url" => "https://api.github.com/marketplace_listing/plans/9",
            "accounts_url" => "https://api.github.com/marketplace_listing/plans/9/accounts",
            "id" => 522,
            "name" => plan_name,
            "description" => "A really, super professional-grade CI solution",
            "monthly_price_in_cents" => 9999,
            "yearly_price_in_cents" => 11998,
            "price_model" => "flat-rate",
            "unit_name" => nil,
            "bullets" => [
              "This is the first bullet of the plan",
              "This is the second bullet of the plan"
            ]
          }
        },
        "owners" => [
          {
            "url" => "https://api.github.com/users/kdaigle",
            "id" => 52,
            "login" => "kdaigle",
            "email" => "kdaigle@github.com"
          }
        ]
      }
    ]
  end

  def self.listing_for_account(account_id = 1, account_type = "Organization", plan_name = "Startup")
    {
      "url" => "https://api.github.com/orgs/github",
      "type" => account_type,
      "id" => account_id,
      "login" => "github",
      "email" => nil,
      "organization_billing_email" => "billing@github.com",
      "marketplace_purchase" => {
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-11-11T00:00:00Z",
        "unit_count" => nil,
        "on_free_trial" => false,
        "free_trial_ends_on" => nil,
        "plan" => {
          "url" => "https://api.github.com/marketplace_listing/plans/8",
          "accounts_url" => "https://api.github.com/marketplace_listing/plans/8/accounts",
          "id" => 8,
          "name" => plan_name,
          "description" => "A professional-grade CI solution",
          "monthly_price_in_cents" => 1099,
          "yearly_price_in_cents" => 11870,
          "price_model" => "flat-rate",
          "has_free_trial" => true,
          "unit_name" => nil,
          "bullets" => [
            "This is the first bullet of the plan",
            "This is the second bullet of the plan"
          ]
        }
      }
    }
  end

  def self.empty_listing_for_account
    {
      "message" => "Not Found",
      "documentation_url" => "https://developer.github.com/v3/apps/marketplace/#check-if-a-github-account-is-associated-with-any-marketplace-listing"
    }
  end
end
