defmodule Secrethub.OpenIDConnect.JWTClaim do
  @moduledoc """
  JWT Claim configuration.
  Defines the structure and available claims for JWT tokens.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t(),
          is_system_claim: boolean(),
          is_aws_tag: boolean(),
          is_mandatory: boolean(),
          is_active: boolean()
        }

  @primary_key false
  embedded_schema do
    field :name, :string
    field :description, :string
    field :is_system_claim, :boolean, default: true
    field :is_aws_tag, :boolean, default: false
    field :is_mandatory, :boolean, default: false
    field :is_active, :boolean, default: true
  end

  @doc """
  Creates a changeset for JWT claim.
  """
  def changeset(claim \\ %__MODULE__{}, attrs) do
    claim
    |> cast(attrs, [:name, :description, :is_system_claim, :is_aws_tag, :is_mandatory, :is_active])
    |> validate_required([:name, :description])
  end

  @doc """
  Returns a map of all standard JWT claims where keys are claim names.
  """
  def standard_claims do
    Map.merge(mandatory_claims(), optional_claims())
  end

  @doc """
  Returns a map of mandatory JWT claims where keys are claim names.
  """
  def mandatory_claims do
    %{
      "exp" => %__MODULE__{
        name: "exp",
        description: "Expiration Time - Time after which the JWT expires",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      },
      "iat" => %__MODULE__{
        name: "iat",
        description: "Issued At - Time at which the JWT was issued",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      },
      "nbf" => %__MODULE__{
        name: "nbf",
        description: "Not Before - Time before which the JWT must not be accepted for processing",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      },
      "iss" => %__MODULE__{
        name: "iss",
        description: "Issuer - Identifies principal that issued the JWT",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      },
      "aud" => %__MODULE__{
        name: "aud",
        description: "Audience - Recipient for which the JWT is intended",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      },
      "jti" => %__MODULE__{
        name: "jti",
        description:
          "JWT ID - Unique identifier that can be used to prevent the JWT from being replayed",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: true,
        is_active: true
      }
    }
  end

  @doc """
  Returns a map of optional JWT claims where keys are claim names.
  """
  def optional_claims do
    %{
      "sub" => %__MODULE__{
        name: "sub",
        description:
          "Subject of the JWT - Identifies the principal that is the subject of the JWT",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "sub127" => %__MODULE__{
        name: "sub127",
        description:
          "Compact subject (org:project_id:repo:ref_type:ref) stripped of ':' characters, ref without leading 'refs/', capped at 127 chars",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "org_id" => %__MODULE__{
        name: "org_id",
        description: "Organization ID",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "prj_id" => %__MODULE__{
        name: "prj_id",
        description: "Project ID associated with the workflow",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "wf_id" => %__MODULE__{
        name: "wf_id",
        description: "Workflow ID",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "ppl_id" => %__MODULE__{
        name: "ppl_id",
        description: "Pipeline ID",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "job_id" => %__MODULE__{
        name: "job_id",
        description: "Job ID",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "repo" => %__MODULE__{
        name: "repo",
        description: "Repository name",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "actor" => %__MODULE__{
        name: "actor",
        description: "User ID who triggered the promotion (can be NULL)",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "tag" => %__MODULE__{
        name: "tag",
        description: "Git tag that triggered the pipeline",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "ref" => %__MODULE__{
        name: "ref",
        description: "Git reference that triggered the pipeline",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "ref_type" => %__MODULE__{
        name: "ref_type",
        description: "Git reference type that triggered the pipeline",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "branch" => %__MODULE__{
        name: "branch",
        description: "Branch name",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "pr" => %__MODULE__{
        name: "pr",
        description: "Pull-request number that triggered the job",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      },
      "job_type" => %__MODULE__{
        name: "job_type",
        description: "Job type (pipeline_job, debug_job, or debug_project_job)",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "pr_branch" => %__MODULE__{
        name: "pr_branch",
        description: "Branch name which pull request originated from",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "repo_slug" => %__MODULE__{
        name: "repo_slug",
        description: "Repository slug in format owner/repo (e.g., semaphoreio/semaphore)",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "trg" => %__MODULE__{
        name: "trg",
        description:
          "Triggerer details in format <wf_triggerer>:<wf_rerun>-<ppl_triggerer>:<ppl_rerun>",
        is_system_claim: true,
        is_aws_tag: true,
        is_mandatory: false,
        is_active: true
      },
      "org" => %__MODULE__{
        name: "org",
        description: "Organization name",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: false
      },
      "prj" => %__MODULE__{
        name: "prj",
        description: "Project name associated with the workflow",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: false
      },
      "https://aws.amazon.com/tags" => %__MODULE__{
        name: "https://aws.amazon.com/tags",
        description:
          "AWS-specific tags including project ID, branch, ref type, job type, repo slug, and trigger info",
        is_system_claim: true,
        is_aws_tag: false,
        is_mandatory: false,
        is_active: true
      }
    }
  end

  def disable_on_prem_claims(claims) do
    if Secrethub.on_prem?() do
      Enum.reduce(disabled_on_prem_claims(), claims, fn claim, acc ->
        update_in(acc, [claim], fn claim_config ->
          Map.put(claim_config, :is_active, false)
        end)
      end)
    else
      claims
    end
  end

  defp disabled_on_prem_claims, do: ["pr_branch", "repo"]
end
