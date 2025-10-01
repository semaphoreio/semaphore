import { Link } from "react-router-dom";
import { EnvironmentType } from "../types";
import { Box, MaterializeIcon } from "js/toolbox";
import { EnvironmentSectionIcon, Loader } from "../utils/elements";

interface EnvironmentsListProps {
  environments: EnvironmentType[];
  canManage: boolean;
  loading: boolean;
  error: string | null;
}

export const EnvironmentsList = ({
  environments,
  canManage,
  loading,
  error,
}: EnvironmentsListProps) => {
  if (loading) {
    return <Loader content="Loading environments"/>;
  }

  if (error) {
    return (
      <Box type="danger" className="ma3">
        <p className="ma0">{error}</p>
      </Box>
    );
  }

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <div className="mw8 center">
        <div className="flex items-center justify-between mb4">
          <div>
            <h1 className="f3 ma0 mb2">Ephemeral Environments</h1>
            <p className="f5 gray ma0">
              Quick and easy testing environments for your projects
            </p>
          </div>
          {canManage && (
            <Link to="/new" className="btn btn-primary">
              Create New Environment
            </Link>
          )}
        </div>

        {environments.length === 0 ? (
          <div className="bg-white ba b--black-10 br3 pa5 tc">
            <p className="f4 gray mb3">No environments yet</p>
            <p className="f6 gray mb4">
              Create your first environment type to enable quick provisioning of
              test environments.
            </p>
            {canManage && (
              <Link to="/new" className="btn btn-primary">
                Create First Environment
              </Link>
            )}
          </div>
        ) : (
          <div className="flex flex-column gap-2">
            {environments.map((environment) => (
              <EnvironmentRow key={environment.id} environment={environment}/>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

interface EnvironmentRowProps {
  environment: EnvironmentType;
}

const EnvironmentRow = ({ environment }: EnvironmentRowProps) => {
  const getStatusColor = (state: EnvironmentType[`state`]) => {
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

  const getStatusBadge = (state: EnvironmentType[`state`]) => {
    const color = getStatusColor(state);
    return (
      <span
        className={`f7 fw5 ${color} br2 ph2 pv1 bg-${
          color === `gray` ? `black` : color
        }-10`}
      >
        {state.toUpperCase()}
      </span>
    );
  };

  const projectsCount = environment.projectAccess?.length || 0;
  const projectNames =
    environment.projectAccess
      ?.slice(0, 3)
      .map((p) => p.projectName)
      .join(`, `) || `None`;
  const moreProjects = projectsCount > 3 ? ` +${projectsCount - 3} more` : ``;
  const contextVarsCount = environment.environmentContext?.length || 0;
  const hasTTL = environment.ttlConfig?.default_ttl_hours !== 0;

  const maxInstances = environment.maxInstances;
  const activeInstances = Math.floor(Math.random() * (maxInstances + 1));
  const capacityPercentage =
    maxInstances > 0 ? (activeInstances / maxInstances) * 100 : 0;

  return (
    <Link
      to={`/${environment.id}`}
      className="db bg-white ba b--black-10 br3 pa3 pointer hover-shadow-1 transition-shadow link black"
    >
      <div className="flex items-start gap-3">
        {/* Left side - Main info */}
        <div className="flex-auto">
          <div className="flex items-center gap-2 mb2">
            <h3 className="f5 ma0">{environment.name}</h3>
            {getStatusBadge(environment.state)}
          </div>
          {environment.description && (
            <p className="f6 gray ma0 mb2">{environment.description}</p>
          )}

          {/* Metadata row */}
          <div className="flex items-center gap-3 f7 gray">
            <div className="flex items-center gap-1">
              <EnvironmentSectionIcon sectionId="project_access"/>
              <span className="fw5">Projects:</span>
              <span>
                {projectNames}
                {moreProjects}
              </span>
            </div>
            <div className="flex items-center gap-1">
              <EnvironmentSectionIcon sectionId="context"/>
              <span>
                {contextVarsCount} context{` `}
                {contextVarsCount === 1 ? `var` : `vars`}
              </span>
            </div>
            <div className="flex items-center gap-1">
              <EnvironmentSectionIcon sectionId="ttl"/>
              <span>
                {hasTTL
                  ? `${environment.ttlConfig?.default_ttl_hours}h TTL`
                  : `No expiration`}
              </span>
            </div>
          </div>
        </div>

        {/* Right side - Instance capacity meter */}
        <div className="flex flex-column items-end" style="min-width: 200px;">
          <div className="f7 gray mb1 tr">Instance Capacity</div>
          <div className="w-100 mb1">
            <div
              className="meter br2 overflow-hidden"
              style="height: 20px; background-color: #e0e0e0;"
            >
              <div
                className="meter-fill bg-blue"
                style={`height: 100%; width: ${capacityPercentage}%; transition: width 0.3s ease;`}
                title={`${activeInstances} / ${maxInstances} instances`}
              />
            </div>
          </div>
          <div className="f7 gray tr">
            {activeInstances} / {maxInstances} active
          </div>
        </div>

        {/* Arrow */}
        <div className="flex items-center">
          <MaterializeIcon name="chevron_right" className="gray"/>
        </div>
      </div>
    </Link>
  );
};
