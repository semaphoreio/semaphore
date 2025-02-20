import { h } from "preact";
import { useContext } from "preact/hooks";
import * as stores from "../stores";

interface IntegrationStarterProps {
  connectButtonUrl: string;
}
export const IntegrationStarter = (props: IntegrationStarterProps) => {
  const config = useContext(stores.Config.Context);
  const submitManifest = (e: Event) => {
    e.preventDefault();

    const urlWithToken = new URL(props.connectButtonUrl);
    urlWithToken.searchParams.append(`org_id`, config.orgId);

    window.location.href = urlWithToken.toString();
  };

  return (
    <form
      className="d-flex flex-items-center"
      onSubmit={submitManifest}
      method="post"
    >
      <button
        className="btn btn-primary btn-small"
      >
        Connect
      </button>
    </form>
  );
};