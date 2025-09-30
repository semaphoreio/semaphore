import { Link } from "react-router-dom";
import { EnvironmentForm } from "../components/EnvironmentForm";

export const CreateEnvironmentPage = () => {
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
            <li className="dib gray">Create New</li>
          </ol>
        </nav>

        <div className="mb4">
          <h1 className="f2 f1-m lh-title mb2">Create Environment</h1>
          <p className="mb0 measure-wide gray">
            Set up a new environment type that can be provisioned on-demand for
            your projects.
          </p>
        </div>

        <EnvironmentForm/>
      </div>
    </div>
  );
};
