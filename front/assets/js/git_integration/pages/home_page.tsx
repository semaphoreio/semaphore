/* eslint-disable quotes */
import { Fragment } from "preact";
import { Box, Card } from "../components";
import { useContext } from "preact/hooks";
import * as stores from "../stores";
import { gitSvg, addNewIcon } from "./home_page/icons";

export const HomePage = () => {
  return (
    <div>
      <h2 className="f3 f2-m mb0">Git Integrations</h2>
      <p className="measure">
        Connect Semaphore application with your repositories.
      </p>
      <Integrations/>
      <AddNewIntegration/>
    </div>
  );
};

const Integrations = () => {
  const config = useContext(stores.Config.Context);
  const itemsLen = config.integrations ? config.integrations.length : 0;

  return (
    <Fragment>
      {itemsLen != 0 && (
        <Box boxTitle="Integrations" boxIcon={gitSvg}>
          {config.integrations.map((integration, index) => (
            <Card
              key={index}
              title={integration.appName}
              description={integration.description}
              lastItem={itemsLen === index + 1}
              connectionStatus={integration.connectionStatus}
              integrationType={integration.type}
            />
          ))}
        </Box>
      )}
    </Fragment>
  );
};

const AddNewIntegration = () => {
  const config = useContext(stores.Config.Context);
  const itemsLen = config.newIntegrations ? config.newIntegrations.length : 0;

  return (
    <Fragment>
      {itemsLen != 0 && (
        <Box boxTitle="Connect new" boxIcon={addNewIcon}>
          {config.newIntegrations.map((integration, index) => (
            <Card
              key={index}
              title={integration.name}
              description={integration.description}
              lastItem={itemsLen === index + 1}
              time={integration.setupTime}
              integrationType={integration.type}
              connectButtonUrl={integration.connectUrl}
              internalSetup={integration.internalSetup}
            />
          ))}
        </Box>
      )}
    </Fragment>
  );
};
