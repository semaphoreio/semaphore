import { useState, useContext, useEffect, useCallback } from "preact/hooks";
import { Link } from "react-router-dom";
import { ConfigContext } from "../config";
import { EnvironmentType } from "../types";
import { EphemeralEnvironmentsAPI } from "../utils/api";
import { EnvironmentsList } from "../components/EnvironmentsList";

export const EnvironmentsListPage = () => {
  const config = useContext(ConfigContext);
  const api = new EphemeralEnvironmentsAPI(config);

  const [environments, setEnvironments] = useState<EnvironmentType[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadEnvironments = useCallback(async () => {
    setLoading(true);
    setError(null);

    const response = await api.list();

    if (response.error) {
      setError(response.error || `Failed to load ephemeral environments`);
    } else if (response.data) {
      setEnvironments(response.data.environment_types || []);
    }

    setLoading(false);
  }, []);

  useEffect(() => {
    void loadEnvironments();
  }, []);

  const handleEnvironmentClick = (environment: EnvironmentType) => {
    // Navigation will be handled by Link in EnvironmentCard
  };

  const handleCreateClick = () => {
    // Navigation will be handled by Link
  };

  return (
    <EnvironmentsList
      environments={environments}
      onEnvironmentClick={handleEnvironmentClick}
      onCreateClick={handleCreateClick}
      canManage={config.canManage}
      loading={loading}
      error={error}
    />
  );
};
