/* eslint-disable quotes */

import { useContext, useLayoutEffect } from "preact/hooks";
import * as stores from "../../stores";
import * as components from "../../components";
import { useSteps } from "../../stores/create/steps";

export const SelectProjectType = () => {
  const { dispatch } = useSteps();

  const steps = [
    { id: `select-type`, title: `Select project type` },
    { id: `setup-project`, title: `Setup the project` },
    { id: `select-environment`, title: `Select the environment` },
    { id: `setup-workflow`, title: `Setup workflow` },
  ];
  useLayoutEffect(() => {
    dispatch([`SET_STEPS`, steps]);
  }, []);

  return (
    <div className="flex-l">
      <components.InfoPanel
        title="Project type"
        subtitle="Select how to start your project configuration."
        additionalInfo="Each project is linked to a single repository for streamlined CI/CD management."
        svgPath="images/ill-girl-showing-continue.svg"
      />
      {/* <!-- RIGHT SIDE --> */}
      <Providers/>
    </div>
  );
};

const Providers = () => {
  const config = useContext(stores.Create.Config.Context);

  // Create a new array to avoid mutating the original
  const sortedProviders = [...(config.providers || [])];

  // If we have a primary provider, move it to the front
  if (config.primaryProvider) {
    const primaryIndex = sortedProviders.findIndex(
      (p) => p.type === config.primaryProvider.type
    );

    if (primaryIndex > -1) {
      const [primary] = sortedProviders.splice(primaryIndex, 1);
      sortedProviders.unshift(primary);
    }
  }

  return (
    <div className="w-two-thirds">
      <div className="pb3 mb3 bb b--black-10">
        <div className="flex justify-between items-center">
          <div>
            <h2 className="f3 fw6 mb2">Configuration Method</h2>
            <p className="black-70 mv0">Begin by choosing how you want to set up your project.</p>
          </div>
        </div>
      </div>
      {sortedProviders.map((provider, index) => (
        <components.Card
          key={index}
          type={provider.type}
          status={provider.status}
          setupIntegrationUrl={config.setupIntegrationUrl}
        />
      ))}
    </div>
  );
};
