
import { useContext } from "preact/hooks";
import { NavLink, useLocation } from "react-router-dom";
import * as stores from "../stores";

export const Navigation = () => {
  const { search } = useLocation();
  const config = useContext(stores.Config.Context);

  const { state } = useContext(stores.Spendings.Context);
  const displaySeats = state.selectedSpending?.plan.hasDetails();
  const displayCredits = state.currentSpending?.plan.withCreditsPage();

  const displayProjects = config.projectSpendings;
  const hasPlans = config.availablePlans.length > 0;

  const className = ({ isActive }: { isActive: boolean }) => {
    return (
      `link db pv1 ph2 br3 ` +
      (isActive ? `white active bg-green` : `dark-gray hover-bg-lightest-gray`)
    );
  };

  return (
    <div className="bb bn-l b--black-10 pb3">
      <div className="lh-title measure pb2 mb3">
        <div className="gray">
          Get insights about the your spending, past invoices and update your
          plan.
        </div>
      </div>
      <NavLink to={`/overview${search}`} className={className}>
        Overview
      </NavLink>
      {hasPlans && (
        <NavLink to={`/plans${search}`} className={className}>
          Change Plan
        </NavLink>
      )}
      <div className="f7 gray mb2 mt3">DETAILED BREAKDOWN</div>
      <NavLink to={`/spending${search}`} className={className}>
        Spending
      </NavLink>
      {displayProjects && (
        <NavLink to={`/projects${search}`} className={className}>
          Projects
        </NavLink>
      )}
      {displaySeats && (
        <NavLink to={`/seats${search}`} className={className}>
          Seats
        </NavLink>
      )}
      {displayCredits && (
        <NavLink to={`/credits${search}`} className={className}>
          Credits
        </NavLink>
      )}
    </div>
  );
};
