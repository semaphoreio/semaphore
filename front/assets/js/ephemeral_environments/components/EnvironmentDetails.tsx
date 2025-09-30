import { useState } from "preact/hooks";
import { Link } from "react-router-dom";
import {
  EnvironmentDetails as EnvironmentDetailsType,
  EnvironmentInstance,
} from "../types";
import { Box, Formatter } from "js/toolbox";

interface EnvironmentDetailsProps {
  environment: EnvironmentDetailsType;
  onBack: () => void;
  onEdit: () => void;
  onDelete: () => void;
  onProvision: () => void;
  onDeprovision: (instanceId: string) => void;
  canManage: boolean;
}

export const EnvironmentDetails = ({
  environment,
  onEdit,
  onDelete,
  onProvision,
  onDeprovision,
  canManage,
}: EnvironmentDetailsProps) => {
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);

  const getInstanceStatusIcon = (state: EnvironmentInstance[`state`]) => {
    if (state === `ready_to_use` || state === `in_use`) {
      return <span className="dib w1 h1 br-100 bg-green mr2"/>;
    } else if (state === `provisioning` || state === `deploying`) {
      return <span className="dib w1 h1 br-100 bg-gold mr2"/>;
    } else if (state.startsWith(`failed`)) {
      return <span className="dib w1 h1 br-100 bg-red mr2"/>;
    }
    return <span className="dib w1 h1 br-100 bg-gray mr2"/>;
  };

  const getInstanceStatusText = (state: EnvironmentInstance[`state`]) => {
    return state.replace(/_/g, ` `);
  };

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <div className="mw8 center">
        <nav className="mb4">
          <ol className="list ma0 pa0 f6">
            <li className="dib mr2">
              <Link to="/" className="pointer flex items-center f6">
                Environments
              </Link>
            </li>
            <li className="dib mr2 gray">/</li>
            <li className="dib gray">{environment.name}</li>
          </ol>
        </nav>

        <div className="bg-white ba b--black-10 br3 pa4 mb4">
          <div className="flex items-start justify-between mb3">
            <div>
              <h2 className="f3 ma0 mb2">{environment.name}</h2>
              {environment.description && (
                <p className="f5 gray ma0 mb3">{environment.description}</p>
              )}
              <div className="flex items-center">
                <span className="f6 gray mr3">
                  Last modified by {environment.last_updated_by} on {` `}
                  {new Date(environment.updated_at).toLocaleDateString(
                    `en-US`,
                    {
                      year: `numeric`,
                      month: `short`,
                      day: `numeric`,
                    }
                  )}
                </span>
              </div>
            </div>
            {canManage && (
              <div className="flex">
                <button className="btn btn-secondary mr2" onClick={onEdit}>
                  Edit
                </button>
                <button className="btn btn-secondary" onClick={onDelete}>
                  Remove
                </button>
              </div>
            )}
          </div>

          <div className="bt b--black-10 pt3">
            <div className="flex items-center justify-between mb3">
              <p className="f6 gray ma0">
                Available to use in: Saas, alles, semaphore, alex_test_project
                and 11 more projects
              </p>
              {canManage && (
                <button className="btn btn-primary" onClick={onProvision}>
                  Provision new instance
                </button>
              )}
            </div>

            {!environment.instances || environment.instances.length === 0 ? (
              <Box type="info" className="mt3">
                <p className="ma0">
                  No instances provisioned yet. Click &quot;Provision new
                  instance&quot; to create one.
                </p>
              </Box>
            ) : (
              <div className="mt3">
                <table className="w-100">
                  <tbody>
                    {environment.instances.map((instance) => (
                      <tr key={instance.id} className="bb b--black-10">
                        <td className="pv3 pr3 w2">
                          {getInstanceStatusIcon(instance.state)}
                        </td>
                        <td className="pv3 pr3">
                          <div>
                            {instance.url ? (
                              <a
                                href={instance.url}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="link blue hover-dark-blue fw5"
                              >
                                {instance.name}
                              </a>
                            ) : (
                              <span className="fw5">{instance.name}</span>
                            )}
                            {instance.url && (
                              <div className="f7 gray mt1">{instance.url}</div>
                            )}
                          </div>
                        </td>
                        <td className="pv3 pr3 f6 gray">
                          {instance.state === `ready_to_use` &&
                            instance.provisioned_at && (
                            <div>
                                provisioned on{` `}
                              {new Date(
                                instance.provisioned_at
                              ).toLocaleDateString()}
                              {` `}
                                by amir
                              <br/>
                                last deployed to{` `}
                              {Formatter.formatTimeAgo(instance.updated_at)}
                              {` `}
                                by {instance.deployed_by || `unknown`}
                            </div>
                          )}
                          {instance.state === `provisioning` && (
                            <div className="gold">provisioning</div>
                          )}
                          {instance.state.startsWith(`failed`) && (
                            <div className="red">
                              {getInstanceStatusText(instance.state)}
                            </div>
                          )}
                        </td>
                        <td className="pv3 tc">
                          {canManage && (
                            <>
                              {confirmDelete === instance.id ? (
                                <div className="flex items-center">
                                  <span className="f6 mr2">Are you sure?</span>
                                  <button
                                    className="btn btn-tiny btn-danger mr1"
                                    onClick={() => {
                                      onDeprovision(instance.id);
                                      setConfirmDelete(null);
                                    }}
                                  >
                                    Yes
                                  </button>
                                  <button
                                    className="btn btn-tiny btn-secondary"
                                    onClick={() => setConfirmDelete(null)}
                                  >
                                    No
                                  </button>
                                </div>
                              ) : (
                                <button
                                  className="btn btn-secondary"
                                  onClick={() => setConfirmDelete(instance.id)}
                                  disabled={instance.state === `provisioning`}
                                >
                                  {instance.state === `provisioning`
                                    ? `Provisioning...`
                                    : instance.state.startsWith(`failed`)
                                      ? `Dismiss`
                                      : `Deprovision`}
                                </button>
                              )}
                            </>
                          )}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
