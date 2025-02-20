import { h, createContext } from "preact";
import { Insights } from "./components/insights";
import { BrowserRouter } from "react-router-dom";

export interface AppConfig {
  defaultBranchName: string;
  baseUrl: string;
  pipelinePerformanceUrl: string;
  pipelineFrequencyUrl: string;
  pipelineReliabilityUrl: string;
  summaryUrl: string;
  settingsUrl: string;
  insightsSettingsUrl: string;
  dashboardsUrl: string;
  availableDatesUrl: string;
}

export const Config = createContext<AppConfig>({
  defaultBranchName: ``,
  baseUrl: ``,
  pipelinePerformanceUrl: ``,
  pipelineFrequencyUrl: ``,
  pipelineReliabilityUrl: ``,
  summaryUrl: ``,
  settingsUrl: ``,
  insightsSettingsUrl: ``,
  dashboardsUrl: ``,
  availableDatesUrl: ``,
});

export const App = ({ config }: { config: AppConfig, }) => {
  return (
    <BrowserRouter basename={config.baseUrl}>
      <Config.Provider value={config}>
        <Insights/>
      </Config.Provider>
    </BrowserRouter>
  );
};
