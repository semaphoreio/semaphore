import { useContext, useState } from "preact/hooks";
import { NavLink } from "react-router-dom";
import * as stores from "../stores";

export const GithubAppSetup = () => {
  const config = useContext(stores.Config.Context);
  const [accountType, setAccountType] = useState<"personal" | "organization">("personal");
  const [isPublic, setIsPublic] = useState(false);
  const [organizationName, setOrganizationName] = useState("");

  const githubAppIntegration = config.newIntegrations?.find(
    (integration) => integration.type === "github_app"
  );

  if (!githubAppIntegration) {
    return (
      <div>
        <NavLink className="gray link f6 mb2 dib" to="/">
          ← Back to Integrations
        </NavLink>
        <p>GitHub App integration not available</p>
      </div>
    );
  }

  const submitManifest = (e: Event) => {
    e.preventDefault();

    const urlWithToken = new URL(githubAppIntegration.connectUrl);
    urlWithToken.searchParams.append(`org_id`, config.orgId);
    urlWithToken.searchParams.append(`is_public`, isPublic ? "true" : "false");

    if (accountType === "organization" && organizationName.trim()) {
      urlWithToken.searchParams.append(`organization`, organizationName.trim());
    }

    window.location.href = urlWithToken.toString();
  };

  return (
    <div>
      <NavLink className="gray link f6 mb2 dib" to="/">
        ← Back to Integrations
      </NavLink>
      <h2 className="f3 f2-m mb0">GitHub App</h2>
      <p className="measure">
        GitHub Cloud integration through installed GitHub App.
      </p>

      <div className="pv3 bt b--lighter-gray">
        <div className="mb1">
          <label className="b mr1">Setup Configuration</label>
        </div>
        <p className="mb3">
          Choose where to create the GitHub App and configure its visibility settings.
        </p>

        <form onSubmit={submitManifest}>
          <div className="mv3 br3 shadow-3 bg-white pa3 bb b--black-075">
            <div className="flex items-center mb2 pb3 bb bw1 b--black-075">
              <span className="material-symbols-outlined mr2">settings</span>
              <span className="b f5">GitHub App Configuration</span>
            </div>

            <div className="mb3">
              <label className="b db mb2">Account Type</label>
              <div className="mb2">
                <label className="flex items-center pointer">
                  <input
                    type="radio"
                    name="accountType"
                    value="personal"
                    checked={accountType === "personal"}
                    onChange={() => setAccountType("personal")}
                    className="mr2"
                  />
                  <span>Personal Account</span>
                </label>
              </div>
              <div className="mb2">
                <label className="flex items-center pointer">
                  <input
                    type="radio"
                    name="accountType"
                    value="organization"
                    checked={accountType === "organization"}
                    onChange={() => setAccountType("organization")}
                    className="mr2"
                  />
                  <span>Organization Account</span>
                </label>
              </div>

              {accountType === "organization" && (
                <div className="mt3">
                  <label className="db mb2" htmlFor="organizationName">
                    Organization Name
                  </label>
                  <input
                    id="organizationName"
                    type="text"
                    value={organizationName}
                    onChange={(e) => setOrganizationName((e.target as HTMLInputElement).value)}
                    placeholder="e.g., my-company"
                    className="form-control w-100"
                    required
                  />
                  <p className="f6 gray mt2 mb0">
                    The exact name of your GitHub organization
                  </p>
                </div>
              )}
            </div>

            <div className="mb3 pt3 bt b--black-075">
              <label className="b db mb2">App Visibility</label>
              <label className="flex items-start pointer">
                <input
                  type="checkbox"
                  checked={isPublic}
                  onChange={(e) => setIsPublic((e.target as HTMLInputElement).checked)}
                  className="mr2 mt1"
                />
                <div>
                  <span className="db mb1">Make app public</span>
                  <span className="f6 gray db">
                    {isPublic
                      ? "Public apps can be installed by anyone and may appear in GitHub's marketplace."
                      : `Private apps only work with ${
                          accountType === "organization" ? "the specified organization" : "your personal account"
                        }. They cannot be installed elsewhere.`}
                  </span>
                </div>
              </label>
            </div>
          </div>

          <div className="mt3">
            <button type="submit" className="btn btn-primary">
              Continue to GitHub
            </button>
            <NavLink to="/" className="ml3 link gray">
              Cancel
            </NavLink>
          </div>
        </form>
      </div>
    </div>
  );
};
