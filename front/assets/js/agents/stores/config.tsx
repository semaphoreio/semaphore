import { createContext } from "preact";
import { AccessProvider, FeatureProvider } from "js/toolbox";

export class State {
  baseUrl: string;
  activityRefreshUrl: string;
  activityStopUrl: string;
  selfHostedUrl: string;
  activity?: any;
  refreshPeriod?: number;
  docsDomain: string;
  accessProvider: AccessProvider;
  featureProvider: FeatureProvider;

  static fromJSON(json: any): State {
    const state = new State();
    state.baseUrl = json.baseUrl;
    state.activityRefreshUrl = json.activityRefreshUrl;
    state.activityStopUrl = json.activityStopUrl;
    state.selfHostedUrl = json.selfHostedUrl;
    state.activity = json.activity;
    state.refreshPeriod = json.refreshPeriod;
    state.docsDomain = json.docsDomain;
    state.accessProvider = AccessProvider.fromJSON(json.permissions);
    state.featureProvider = FeatureProvider.fromJSON(json.features);
    return state;
  }
}

export const Context = createContext<State>({
  baseUrl: ``,
  activityRefreshUrl: ``,
  activityStopUrl: ``,
  selfHostedUrl: ``,
  refreshPeriod: 5000,
  featureProvider: new FeatureProvider(),
  accessProvider: new AccessProvider(),
  docsDomain: ``,
});
