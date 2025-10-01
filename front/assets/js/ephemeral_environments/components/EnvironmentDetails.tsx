import { useState } from "preact/hooks";
import { Link } from "react-router-dom";
import {
  EnvironmentDetails as EnvironmentDetailsType,
  EnvironmentInstance,
  EnvironmentType,
} from "../types";
import { Box, Formatter, MaterializeIcon } from "js/toolbox";
import { EnvironmentSectionIcon } from "../utils/elements";

interface EnvironmentDetailsProps {
  environment: EnvironmentDetailsType;
  onDelete: () => void;
  onProvision: () => void;
  onDeprovision: (instanceId: string) => void;
  canManage: boolean;
}

export const EnvironmentDetails = ({
  environment,
  onDelete,
  onProvision,
  onDeprovision,
  canManage,
}: EnvironmentDetailsProps) => {
  const [confirmDelete, setConfirmDelete] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<`instances` | `configuration`>(
    `instances`
  );

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

  const getStatusColor = (state: EnvironmentDetailsType[`state`]) => {
    switch (state) {
      case `ready`:
        return `green`;
      case `draft`:
        return `gray`;
      case `cordoned`:
        return `gold`;
      case `deleted`:
        return `red`;
      default:
        return `gray`;
    }
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

        {/* Header */}
        <div className="bg-white ba b--black-10 br3 pa4 mb4">
          <div className="flex items-start justify-between mb3">
            <div className="flex-auto">
              <div className="flex items-center mb2">
                <h2 className="f3 ma0 mr3">{environment.name}</h2>
                <span
                  className={`f7 fw5 ${getStatusColor(
                    environment.state
                  )} br2 ph2 pv1 bg-${
                    getStatusColor(environment.state) === `gray`
                      ? `black`
                      : getStatusColor(environment.state)
                  }-10`}
                >
                  {environment.state.toUpperCase()}
                </span>
              </div>
              {environment.description && (
                <p className="f5 gray ma0 mb3 lh-copy">
                  {environment.description}
                </p>
              )}
              <div className="flex items-center f6 gray">
                <MaterializeIcon name="schedule" className="f6 mr1"/>
                <span>
                  Updated {Formatter.formatTimeAgo(environment.updated_at)} by
                  {` `}
                  {environment.last_updated_by}
                </span>
              </div>
            </div>
            {canManage && (
              <div className="flex gap-2">
                <Link
                  className="btn btn-secondary flex items-center gap-1"
                  to="edit"
                >
                  <MaterializeIcon name="edit"/>
                  Edit
                </Link>
                <button
                  className="btn btn-danger flex items-center gap-1"
                  onClick={onDelete}
                >
                  <MaterializeIcon name="delete"/>
                  Remove
                </button>
              </div>
            )}
          </div>

          {/* Quick Stats */}
          <div className="bt b--black-10 pt3">
            <div className="flex flex-wrap gap-4">
              <div className="flex items-center gap-2">
                <EnvironmentSectionIcon
                  sectionId="instances"
                  className="gray"
                />
                <div>
                  <div className="f7 gray">Instances</div>
                  <div className="f5 fw5">
                    {environment.instances?.length || 0} /{` `}
                    {environment.maxInstances}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <EnvironmentSectionIcon
                  sectionId="project_access"
                  className="gray"
                />
                <div>
                  <div className="f7 gray">Project Access</div>
                  <div className="f5 fw5">
                    {environment.projectAccess?.length === 0
                      ? `None`
                      : `${environment.projectAccess?.length || 0} projects`}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <EnvironmentSectionIcon sectionId="context" className="gray"/>
                <div>
                  <div className="f7 gray">Context Variables</div>
                  <div className="f5 fw5">
                    {environment.environmentContext?.length || 0}
                  </div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <EnvironmentSectionIcon sectionId="ttl" className="gray"/>
                <div>
                  <div className="f7 gray">TTL</div>
                  <div className="f5 fw5">
                    {environment.ttlConfig?.default_ttl_hours
                      ? `${environment.ttlConfig.default_ttl_hours}h`
                      : `No expiration`}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="bg-white mt4 br3 ba b--black-10">
          <div className="flex bb b--black-10">
            <button
              className={`pv3 ph4 bn bg-transparent pointer flex items-center gap-1 ${
                activeTab === `instances`
                  ? `fw6 bb bw2 b--blue`
                  : `hover-bg-near-white gray`
              }`}
              onClick={() => setActiveTab(`instances`)}
            >
              <MaterializeIcon name="cloud_queue"/>
              Instances
            </button>
            <button
              className={`pv3 ph4 bn bg-transparent pointer flex items-center gap-1 ${
                activeTab === `configuration`
                  ? `fw6 bb bw2 b--blue`
                  : `hover-bg-near-white gray`
              }`}
              onClick={() => setActiveTab(`configuration`)}
            >
              <MaterializeIcon name="settings"/>
              Configuration
            </button>
          </div>
          <div className="pa4">
            {/* Tab Content */}
            {activeTab === `instances` ? (
              <div className="bg-white">
                <div className="flex items-center justify-between mb3">
                  <h3 className="f4 ma0">Active Instances</h3>
                  {canManage && (
                    <button
                      className="btn btn-primary flex items-center gap-1"
                      onClick={onProvision}
                    >
                      <MaterializeIcon name="add"/>
                      Provision New Instance
                    </button>
                  )}
                </div>

                {!environment.instances ||
                environment.instances.length === 0 ? (
                    <Box type="info">
                      <p className="ma0">
                      No instances provisioned yet. Click &quot;Provision new
                      instance&quot; to create one.
                      </p>
                    </Box>
                  ) : (
                    <div>
                      <table className="w-100">
                        <thead>
                          <tr className="bb b--black-10">
                            <th className="tl pb2 pr3 f6 fw5 gray">Status</th>
                            <th className="tl pb2 pr3 f6 fw5 gray">Name</th>
                            <th className="tl pb2 pr3 f6 fw5 gray">Details</th>
                            <th className="tc pb2 f6 fw5 gray">Actions</th>
                          </tr>
                        </thead>
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
                                    <div className="f7 gray mt1">
                                      {instance.url}
                                    </div>
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
                                    {instance.deployed_by && (
                                      <>
                                        <br/>
                                        last deployed to{` `}
                                        {Formatter.formatTimeAgo(
                                          instance.updated_at
                                        )}
                                        {` `}
                                        by {instance.deployed_by}
                                      </>
                                    )}
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
                                      <div className="flex items-center justify-center">
                                        <span className="f6 mr2">
                                        Are you sure?
                                        </span>
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
                                        onClick={() =>
                                          setConfirmDelete(instance.id)
                                        }
                                        disabled={
                                          instance.state === `provisioning`
                                        }
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
            ) : (
              <EnvironmentConfiguration environment={environment}/>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

interface EnvironmentConfigurationProps {
  environment: EnvironmentType;
}

export const EnvironmentConfiguration = ({
  environment,
}: EnvironmentConfigurationProps) => {
  const getStageLabel = (stageId: string) => {
    switch (stageId) {
      case `provisioning`:
        return { label: `Provisioning`, color: `blue`, icon: `build_circle` };
      case `deployment`:
        return { label: `Deployment`, color: `green`, icon: `rocket_launch` };
      case `deprovisioning`:
        return {
          label: `Deprovisioning`,
          color: `orange`,
          icon: `delete_sweep`,
        };
      default:
        return { label: stageId, color: `gray`, icon: `settings` };
    }
  };

  return (
    <div className="">
      {/* Pipeline Stages - 3 cards */}
      <div className="mb4">
        <h4 className="f5 ma0 mb3 flex items-center gap-1">
          <MaterializeIcon name="settings"/>
          Pipeline Stages
        </h4>
        {environment.stages && environment.stages.length > 0 ? (
          <div className="flex gap-3">
            {environment.stages.map((stage) => {
              const stageInfo = getStageLabel(stage.id);
              return (
                <div key={stage.id} className="flex-1 ba b--black-10 br2 pa2">
                  <div className="flex items-center gap-2 mb3">
                    <MaterializeIcon
                      name={stageInfo.icon}
                      className={stageInfo.color}
                    />
                    <h5 className="f6 ma0 fw6">{stageInfo.label}</h5>
                  </div>

                  {stage.pipeline ? (
                    <div className="f7 mb3">
                      <div className="gray mb1">
                        <span className="fw5">Project:</span>
                        {` `}
                        {stage.pipeline.projectName}
                      </div>
                      {stage.pipeline.branch && (
                        <div className="gray mb1">
                          <span className="fw5">Branch:</span>
                          {` `}
                          {stage.pipeline.branch}
                        </div>
                      )}
                      {stage.pipeline.pipelineYamlFile && (
                        <div className="gray">
                          <span className="fw5">File:</span>
                          {` `}
                          {stage.pipeline.pipelineYamlFile}
                        </div>
                      )}
                    </div>
                  ) : (
                    <div className="f7 gray mb3">Pipeline not configured</div>
                  )}

                  <div className="bt b--black-10 pt2 mb3">
                    <div className="f7 fw5 mb2">Parameters</div>
                    {stage.parameters && stage.parameters.length > 0 ? (
                      <div className="f7 gray">
                        {stage.parameters.map((param) => (
                          <div key={param.name} className="mb1">
                            <span className="code fw5">{param.name}</span>
                            {param.required && <span className="red">*</span>}
                            {param.description && (
                              <span className="ml1">- {param.description}</span>
                            )}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="f7 gray">None</div>
                    )}
                  </div>

                  <div className="bt b--black-10 pt2">
                    <div className="f7 fw5 mb2">Access Control</div>
                    {stage.rbacAccess && stage.rbacAccess.length > 0 ? (
                      <div className="f7 gray">
                        {stage.rbacAccess.map((subject, idx) => (
                          <div
                            key={idx}
                            className="mb1 flex items-center gap-1"
                          >
                            <MaterializeIcon
                              name={
                                subject.type === `user`
                                  ? `person`
                                  : subject.type === `group`
                                    ? `group`
                                    : `key`
                              }
                            />
                            {subject.name || subject.id}
                          </div>
                        ))}
                      </div>
                    ) : (
                      <div className="f7 gray">Not configured</div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        ) : (
          <Box type="info" className="ma0">
            <p className="ma0">No stages configured</p>
          </Box>
        )}
      </div>

      {/* Bottom section - compact grid */}
      <div className="flex gap-3">
        {/* Context Variables */}
        <div className="flex-1 pa2">
          <h4 className="f6 ma0 mb2 flex items-center gap-1 fw6">
            <MaterializeIcon name="code"/>
            Context Variables
          </h4>
          {environment.environmentContext &&
          environment.environmentContext.length > 0 ? (
              <div className="f7 gray">
                {environment.environmentContext.map((ctx) => (
                  <div key={ctx.name} className="mb1">
                    <span className="code fw5">{ctx.name}</span>
                    {ctx.description && <span> - {ctx.description}</span>}
                  </div>
                ))}
              </div>
            ) : (
              <div className="f7 gray">None configured</div>
            )}
        </div>

        {/* Project Access */}
        <div className="flex-1 pa2">
          <h4 className="f6 ma0 mb2 flex items-center gap-1 fw6">
            <MaterializeIcon name="folder"/>
            Project Access
          </h4>
          {environment.projectAccess && environment.projectAccess.length > 0 ? (
            <div className="flex flex-wrap gap-1">
              {environment.projectAccess.map((project) => (
                <span
                  key={project.projectId}
                  className="f7 ba b--black-20 br1 ph2 pv1"
                  title={project.projectDescription || project.projectName}
                >
                  {project.projectName}
                </span>
              ))}
            </div>
          ) : (
            <div className="f7 orange">No projects can access</div>
          )}
        </div>

        {/* TTL */}
        <div className="flex-1 pa2">
          <h4 className="f6 ma0 mb2 flex items-center gap-1 fw6">
            <MaterializeIcon name="schedule"/>
            Lifecycle
          </h4>
          {environment.ttlConfig ? (
            <div className="f7 gray">
              {environment.ttlConfig.default_ttl_hours !== null ? (
                <>
                  <div className="mb1">
                    Expires after{` `}
                    <strong>{environment.ttlConfig.default_ttl_hours}h</strong>
                  </div>
                  <div>
                    Extensions:{` `}
                    {environment.ttlConfig.allow_extension
                      ? `allowed`
                      : `not allowed`}
                  </div>
                </>
              ) : (
                <div>No expiration</div>
              )}
            </div>
          ) : (
            <div className="f7 gray">No TTL configured</div>
          )}
        </div>
      </div>
    </div>
  );
};
