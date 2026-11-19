
import { NavLink } from "react-router-dom";

interface IntegrationStarterProps {
  connectButtonUrl: string;
}

export const IntegrationStarter = (_props: IntegrationStarterProps) => {
  return (
    <NavLink
      className="btn btn-primary btn-small"
      to="/github_app/setup"
    >
      Connect
    </NavLink>
  );
};
