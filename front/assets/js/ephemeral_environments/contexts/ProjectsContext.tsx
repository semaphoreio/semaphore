import { createContext } from "preact";
import { useContext, useState, useEffect, useMemo } from "preact/hooks";
import * as types from "../types";
import { AppConfig } from "./ConfigContext";

interface ProjectsContextValue {
  projects: types.Project[];
  loading: boolean;
  error: string | null;
}

const ProjectsContext = createContext<ProjectsContextValue | null>(null);

interface ProjectsProviderProps {
  children: any;
  config: AppConfig;
}

export const ProjectsProvider = ({ children, config }: ProjectsProviderProps) => {
  const [projects, setProjects] = useState<types.Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void config.apiUrls.projectsList.call().then((response) => {
      if (response.error) {
        setError(response.error);
      } else {
        setProjects(response.data?.projects || []);
      }
      setLoading(false);
    });
  }, [config]);

  const value = useMemo(() => ({ projects, loading, error }), [projects, loading, error]);

  return <ProjectsContext.Provider value={value}>{children}</ProjectsContext.Provider>;
};

export const useProjects = () => {
  const context = useContext(ProjectsContext);
  if (!context) {
    throw new Error(`useProjects must be used within ProjectsProvider`);
  }
  return context;
};
