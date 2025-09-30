import { useContext, useState, useEffect } from "preact/hooks";
import { useParams, Link } from "react-router-dom";
import { ConfigContext } from "../contexts/ConfigContext";
import { EnvironmentDetails } from "../types";
import { EnvironmentForm } from "../components/EnvironmentForm";

export const EditEnvironmentPage = () => {
  const config = useContext(ConfigContext);
  const { id } = useParams();

  const [environment, setEnvironment] = useState<EnvironmentDetails | null>(
    null
  );

  useEffect(() => {
    const loadEnvironment = async () => {
      if (!id) return;

      const response = await config.apiUrls.show.replace({ __ID__: id }).call();

      if (response.error) {
        // eslint-disable-next-line no-console
        console.log(response);
      } else if (response.data) {
        setEnvironment(response.data);
      }
    };

    void loadEnvironment();
  }, [id, config]);

  return (
    <div className="bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075">
      <nav className="mb4">
        <ol className="list ma0 pa0 f6">
          <li className="dib mr2">
            <Link to="/" className="pointer flex items-center f6">
              Environments
            </Link>
          </li>
          <li className="dib mr2 gray">/</li>
          <li className="dib mr2 gray">
            <Link
              to={`/${environment.id}`}
              className="pointer flex items-center f6"
            >
              {environment.name}
            </Link>
          </li>
          <li className="dib mr2 gray">/</li>
          <li className="dib mr2 gray">Edit</li>
        </ol>
      </nav>

      <div className="mb4">
        <h1 className="f2 f1-m lh-title mb2">
          Edit Environment: {environment.name}
        </h1>
        <p className="mb0 measure-wide gray">
          Update the configuration for this ephemeral environment type.
        </p>
      </div>

      <EnvironmentForm environmentId={environment.id}/>
    </div>
  );
};
