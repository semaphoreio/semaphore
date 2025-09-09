import { useContext } from "preact/hooks";
import { useNavigate, Link } from "react-router-dom";
import { ConfigContext } from "../config";
import { CreateEnvironmentData } from "../types";
import { EphemeralEnvironmentsAPI } from "../utils/api";
import { EnvironmentForm } from "../components/EnvironmentForm";

export const CreateEnvironmentPage = () => {
  const config = useContext(ConfigContext);
  const api = new EphemeralEnvironmentsAPI(config);
  const navigate = useNavigate();

  const handleCreate = async (data: CreateEnvironmentData) => {
    const response = await api.create(data);

    if (response.error) {
      console.error(`Failed to create environment:`, response.error);
      throw new Error(response.error);
    } else {
      // Navigate back to list page
      navigate(`/`);
    }
  };

  const handleCancel = () => {
    navigate(`/`);
  };

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <div className="mw8 center">
        <nav className="mb4">
          <ol className="list ma0 pa0 f6">
            <li className="dib mr2">
              <Link
                to="/"
                className="pointer flex items-center f6"
              >
                Environments
              </Link>
            </li>
            <li className="dib mr2 gray">
            /
            </li>
            <li className="dib gray">
            Create New
            </li>
          </ol>
        </nav>

        <div className="mb4">
          <h1 className="f2 f1-m lh-title mb2">Create Environment</h1>
          <p className="mb0 measure-wide gray">
          Set up a new environment type that can be provisioned on-demand for your projects.
          </p>
        </div>

        <EnvironmentForm
          formType="create"
          onCreate={handleCreate}
          onCancel={handleCancel}
          projects={config.projects}
        />
      </div>
    </div>
  );
};
