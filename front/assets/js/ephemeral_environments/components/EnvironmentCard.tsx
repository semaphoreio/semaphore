import { Link } from "react-router-dom";
import { EnvironmentType, InstanceCounts } from "../types";
import { MaterializeIcon, Tooltip } from "js/toolbox";

interface EnvironmentCardProps {
  environment: EnvironmentType;
  counts?: InstanceCounts;
  onClick?: () => void;
}

export const EnvironmentCard = ({
  environment,
  counts,
}: EnvironmentCardProps) => {
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

  const getInstanceBar = () => {
    if (!counts) return null;

    const { pending, running, failed } = counts;
    const maxInstances = environment.max_number_of_instances;

    return (
      <div className="mt2">
        <div className="flex justify-between f7 mb1">
          <span>pending</span>
          <span className="gold">
            {pending}/{maxInstances}
          </span>
        </div>
        <div
          className="w-100 bg-black-10 br2 overflow-hidden"
          style={{ height: `4px` }}
        >
          <div
            className="bg-gold h-100"
            style={{ width: `${(pending / maxInstances) * 100}%` }}
          />
        </div>

        <div className="flex justify-between f7 mb1 mt2">
          <span>running</span>
          <span className="green">
            {running}/{maxInstances}
          </span>
        </div>
        <div
          className="w-100 bg-black-10 br2 overflow-hidden"
          style={{ height: `4px` }}
        >
          <div
            className="bg-green h-100"
            style={{ width: `${(running / maxInstances) * 100}%` }}
          />
        </div>

        {failed > 0 && (
          <>
            <div className="flex justify-between f7 mb1 mt2">
              <span>failed</span>
              <span className="red">
                {failed}/{maxInstances}
              </span>
            </div>
            <div
              className="w-100 bg-black-10 br2 overflow-hidden"
              style={{ height: `4px` }}
            >
              <div
                className="bg-red h-100"
                style={{ width: `${(failed / maxInstances) * 100}%` }}
              />
            </div>
          </>
        )}
      </div>
    );
  };

  const hasFailedProvisioning = counts && counts.failed > 0;

  return (
    <Link
      to={`/${environment.id}`}
      className="db bg-white ba b--black-10 br3 pa3 pointer hover-shadow-1 transition-shadow link black"
    >
      <div className="flex items-start justify-between mb2">
        <h3 className="f5 ma0 lh-title">{environment.name}</h3>
        {hasFailedProvisioning && (
          <Tooltip
            content={`There is one failed provisioning pipeline`}
            placement="top"
            anchor={<MaterializeIcon name="info" className="f5 red pointer"/>}
          />
        )}
      </div>

      {environment.description && (
        <p className="f6 gray mt1 mb2 lh-copy">{environment.description}</p>
      )}

      <div className="flex items-center mb2">
        <span className={`f7 fw5 ${getStatusColor(environment.state)}`}>
          {environment.state.toUpperCase()}
        </span>
      </div>

      {getInstanceBar()}
    </Link>
  );
};
