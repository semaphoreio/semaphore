import { Link } from "react-router-dom";
import { EnvironmentType, InstanceCounts } from "../types";
import { EnvironmentCard } from "./EnvironmentCard";
import { Box } from "js/toolbox";
import { Loader } from "../utils/elements";

interface EnvironmentsListProps {
  environments: EnvironmentType[];
  onEnvironmentClick: (environment: EnvironmentType) => void;
  onCreateClick: () => void;
  canManage: boolean;
  loading: boolean;
  error: string | null;
}

export const EnvironmentsList = ({
  environments,
  onEnvironmentClick,
  onCreateClick,
  canManage,
  loading,
  error
}: EnvironmentsListProps) => {

  // Calculate instance counts for each environment
  // This will be replaced with real data from backend
  const getInstanceCounts = (env: EnvironmentType): InstanceCounts => {
    // Placeholder counts - will be replaced with real data
    return {
      pending: 0,
      running: 0,
      failed: 0,
      total: 0
    };
  };

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
            <p className="f5 gray ma0">
              Your environment types available quick and easy testing of projects
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
              Create your first environment type to enable quick provisioning of test environments.
            </p>
            {canManage && (
              <Link to="/new" className="btn btn-primary">
                Create First Environment
              </Link>
            )}
          </div>
        ) : (
          <div className="grid-container">
            <style dangerouslySetInnerHTML={{ __html: `
              .grid-container {
                display: grid;
                grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
                gap: 1rem;
              }
            ` }}/>
            {environments.map(environment => (
              <EnvironmentCard
                key={environment.id}
                environment={environment}
                counts={getInstanceCounts(environment)}
                onClick={() => onEnvironmentClick(environment)}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
};
