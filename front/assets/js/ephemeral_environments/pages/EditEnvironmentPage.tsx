import { useContext, useState, useEffect } from "preact/hooks";
import { useNavigate, useParams, Link } from "react-router-dom";
import { ConfigContext } from "../config";
import { CreateEnvironmentData, EnvironmentDetails } from "../types";
import { EphemeralEnvironmentsAPI } from "../utils/api";
import { Loader } from "../utils/elements";
import { EnvironmentForm } from "../components/EnvironmentForm";

export const EditEnvironmentPage = () => {
  const config = useContext(ConfigContext);
  const api = new EphemeralEnvironmentsAPI(config);
  const navigate = useNavigate();
  const { id } = useParams();

  const [environment, setEnvironment] = useState<EnvironmentDetails | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadEnvironment = async () => {
      if (!id) return;

      setLoading(true);
      setError(null);

      const response = await api.get(id);

      if (response.error) {
        setError(response.error || `Failed to load environment`);
      } else if (response.data) {
        setEnvironment(response.data);
      }

      setLoading(false);
    };

    void loadEnvironment();
  }, [id]);

  const handleUpdate = async (data: CreateEnvironmentData) => {
    if (!id) return;

    const response = await api.update(id, data);

    if (response.error) {
      console.error(`Failed to update environment:`, response.error);
      throw new Error(response.error);
    } else {
      navigate(`/${id}`);
    }
  };

  const handleCancel = () => {
    navigate(`/${id}`);
  };

  if (loading) {
    return <Loader content="Loading environment..."/>;
  }

  if (error || !environment) {
    return (
      <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
        <p className="red">{error || `Environment not found`}</p>
      </div>
    );
  }

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
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
          <li className="dib mr2 gray">
            <Link
              to={`/${environment.id}`}
              className="pointer flex items-center f6"
            >
              {environment.name}
            </Link>
          </li>
          <li className="dib mr2 gray">
            /
          </li>
          <li className="dib mr2 gray">
            Edit
          </li>
        </ol>
      </nav>

      <div className="mb4">
        <h1 className="f2 f1-m lh-title mb2">Edit Environment: {environment.name}</h1>
        <p className="mb0 measure-wide gray">
          Update the configuration for this ephemeral environment type.
        </p>
      </div>

      <EnvironmentForm
        formType="edit"
        onCreate={handleUpdate}
        onCancel={handleCancel}
        projects={config.projects}
        initialData={{
          name: environment.name,
          description: environment.description,
          max_instances: environment.max_number_of_instances
        }}
      />
    </div>
  );
};
