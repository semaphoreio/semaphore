module RepoHost::Github::Responses::Marketplace::Events
  def self.purchased
    {
      "action" => "purchased",
      "effective_date" => "2017-08-03T12:40:30Z",
      "sender" => {
        "login" => "nikolalsvk",
        "id" => 3028124,
        "avatar_url" => "https://avatars2.githubusercontent.com/u/3028124?v=4",
        "gravatar_id" => "",
        "url" => "https://api.github.com/users/nikolalsvk",
        "html_url" => "https://github.com/nikolalsvk",
        "followers_url" => "https://api.github.com/users/nikolalsvk/followers",
        "following_url" => "https://api.github.com/users/nikolalsvk/following{/other_user}",
        "gists_url" => "https://api.github.com/users/nikolalsvk/gists{/gist_id}",
        "starred_url" => "https://api.github.com/users/nikolalsvk/starred{/owner}{/repo}",
        "subscriptions_url" => "https://api.github.com/users/nikolalsvk/subscriptions",
        "organizations_url" => "https://api.github.com/users/nikolalsvk/orgs",
        "repos_url" => "https://api.github.com/users/nikolalsvk/repos",
        "events_url" => "https://api.github.com/users/nikolalsvk/events{/privacy}",
        "received_events_url" => "https://api.github.com/users/nikolalsvk/received_events",
        "type" => "User",
        "site_admin" => false,
        "email" => "nikolaseap@gmail.com"
      },
      "marketplace_purchase" => {
        "account" => {
          "type" => "User",
          "id" => 3028124,
          "login" => "nikolalsvk",
          "organization_billing_email" => nil
        },
        "billing_cycle" => "monthly",
        "unit_count" => 1,
        "next_billing_date" => nil,
        "plan" => {
          "id" => 256,
          "name" => "Free",
          "description" => "Free for both open source and private repositories",
          "monthly_price_in_cents" => 0,
          "yearly_price_in_cents" => 0,
          "price_model" => "free",
          "unit_name" => nil,
          "bullets" => [
            "Unlimited projects",
            "Unlimited users",
            "2x parallel jobs",
            "100 private jobs, unlimited open source jobs"
          ]
        }
      }
    }
  end

  def self.cancelled(id = 4, account_type = "Organization")
    {
      "action" => "cancelled",
      "effective_date" => "2017-04-06T02:01:16Z",
      "marketplace_purchase" => {
        "account" => {
          "type" => account_type,
          "id" => id,
          "login" => "GitHub"
        },
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-05-01T00:00:00Z",
        "unit_count" => nil,
        "plan" => {
          "id" => 9,
          "name" => "Super Pro",
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
      "sender" => {
        "id" => id,
        "login" => "kdaigle"
      }
    }
  end

  def self.ping
    {
      "zen" => "Non-blocking is better than blocking.",
      "hook_id" => 15646669,
      "hook" => {
        "type" => "Marketplace::Listing",
        "id" => 15646669,
        "name" => "web",
        "active" => true,
        "events" => [
          "push"
        ],
        "config" => {
          "content_type" => "json",
          "insecure_ssl" => "0",
          "url" => "https://stg1-semaphore.semaphoreci.com/github/marketplace_hook"
        },
        "updated_at" => "2017-08-21T11:48:18Z",
        "created_at" => "2017-08-21T11:48:18Z",
        "marketplace_listing_id" => 440
      },
      "sender" => {
        "login" => "nikolalsvk",
        "id" => 3028124,
        "avatar_url" => "https://avatars2.githubusercontent.com/u/3028124?v=4",
        "gravatar_id" => "",
        "url" => "https://api.github.com/users/nikolalsvk",
        "html_url" => "https://github.com/nikolalsvk",
        "followers_url" => "https://api.github.com/users/nikolalsvk/followers",
        "following_url" => "https://api.github.com/users/nikolalsvk/following{/other_user}",
        "gists_url" => "https://api.github.com/users/nikolalsvk/gists{/gist_id}",
        "starred_url" => "https://api.github.com/users/nikolalsvk/starred{/owner}{/repo}",
        "subscriptions_url" => "https://api.github.com/users/nikolalsvk/subscriptions",
        "organizations_url" => "https://api.github.com/users/nikolalsvk/orgs",
        "repos_url" => "https://api.github.com/users/nikolalsvk/repos",
        "events_url" => "https://api.github.com/users/nikolalsvk/events{/privacy}",
        "received_events_url" => "https://api.github.com/users/nikolalsvk/received_events",
        "type" => "User",
        "site_admin" => false
      }
    }
  end

  def self.changed(plan_name = "Bootstrap", id = 4, account_type = "Organization")
    {
      "action" => "changed",
      "effective_date" => "2017-04-06T02:01:16Z",
      "marketplace_purchase" => {
        "account" => {
          "type" => account_type,
          "id" => id,
          "login" => "GitHub"
        },
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-05-01T00:00:00Z",
        "unit_count" => nil,
        "plan" => {
          "id" => 9,
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
      "previous_marketplace_purchase" => {
        "account" => {
          "type" => "Organization",
          "id" => 4,
          "login" => "GitHub"
        },
        "billing_cycle" => "monthly",
        "next_billing_date" => "2017-05-01T00:00:00Z",
        "unit_count" => nil,
        "plan" => {
          "id" => 9,
          "name" => "Super Pro",
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
      "sender" => {
        "id" => id,
        "login" => "kdaigle"
      }
    }
  end
end
