
import { useContext, useEffect, useReducer, useState } from "preact/hooks";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import * as components from "../components";

export const Page = () => {
  const config = useContext(stores.Config.Context);
  const refreshPeriod = config.refreshPeriod || 5000;

  const [refreshing, setRefreshing] = useState(false);

  const [activity, dispatchActivity] = useReducer(stores.Activity.Reducer, {
    ...stores.Activity.EmptyState,
    hostedAgents: config.activity.agent_stats.agent_types.map(
      stores.Activity.Agent.fromJSON
    ),
    selfHostedAgents: config.activity.agent_stats.self_hosted_agent_types.map(
      stores.Activity.Agent.fromJSON
    ),
    waitingItems: config.activity.items.waiting.items.map(
      stores.Activity.Item.fromJSON
    ),
    runningItems: config.activity.items.running.items.map(
      stores.Activity.Item.fromJSON
    ),
    lobbyItems: config.activity.items.lobby.items.map(
      stores.Activity.Item.fromJSON
    ),
  });

  const refreshActivity = async () => {
    setRefreshing(true);
    try {
      const {
        data: { agent_stats, items },
      } = (await toolbox.APIRequest.get(config.activityRefreshUrl)) as any;

      dispatchActivity({
        type: `SET_HOSTED_AGENTS`,
        value: agent_stats.agent_types.map(stores.Activity.Agent.fromJSON),
      });

      dispatchActivity({
        type: `SET_SELF_HOSTED_AGENTS`,
        value: agent_stats.self_hosted_agent_types.map(
          stores.Activity.Agent.fromJSON
        ),
      });

      dispatchActivity({
        type: `SET_WAITING_ITEMS`,
        value: items.waiting.items.map(stores.Activity.Item.fromJSON),
      });

      dispatchActivity({
        type: `SET_RUNNING_ITEMS`,
        value: items.running.items.map(stores.Activity.Item.fromJSON),
      });

      dispatchActivity({
        type: `SET_LOBBY_ITEMS`,
        value: items.lobby.items.map(stores.Activity.Item.fromJSON),
      });

      let invisibleJobsCount = 0;
      invisibleJobsCount += items.running.non_visible_job_count;
      invisibleJobsCount += items.waiting.non_visible_job_count;
      invisibleJobsCount += items.lobby.non_visible_job_count;

      dispatchActivity({
        type: `SET_INVISIBLE_JOBS_COUNT`,
        value: invisibleJobsCount,
      });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
    } finally {
      setRefreshing(false);
    }
  };

  useEffect(() => {
    const interval = setInterval(() => {
      if (refreshing) {
        return;
      } else {
        void refreshActivity();
      }
    }, refreshPeriod);
    return () => clearInterval(interval);
  }, [refreshing]);

  useEffect(() => {
    void refreshActivity();
  }, []);

  return (
    <div className={`bg-washed-gray mt4 pa3 pa4-l br3 ba b--black-075`}>
      <stores.Activity.Context.Provider
        value={{ state: activity, dispatch: dispatchActivity }}
      >
        <components.Agents.SelfHostedList/>
        <components.Agents.HostedList/>
        <components.ActivityMonitor/>
      </stores.Activity.Context.Provider>
    </div>
  );
};
