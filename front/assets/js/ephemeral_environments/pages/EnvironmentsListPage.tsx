import { useState, useContext, useEffect, useCallback } from "preact/hooks";
import { Link } from "react-router-dom";
import { ConfigContext } from "../contexts/ConfigContext";
import { EnvironmentType } from "../types";
import { EnvironmentsList } from "../components/EnvironmentsList";

export const EnvironmentsListPage = () => {
  const config = useContext(ConfigContext);

  const [environments, setEnvironments] = useState<EnvironmentType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadEnvironments = useCallback(async () => {
    setLoading(true);
    setError(null);

    const response = await config.apiUrls.list.call();

    if (response.error) {
      setError(response.error || `Failed to load ephemeral environments`);
    } else if (response.data) {
      setEnvironments(response.data.environment_types || []);
    }

    setLoading(false);
  }, [config]);

  useEffect(() => {
    void loadEnvironments();
  }, []);

  return (
    <EnvironmentsList
      environments={environments}
      canManage={config.canManage}
      loading={loading}
      error={error}
    />
  );
};
