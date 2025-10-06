import { useState, useEffect, useRef } from "preact/hooks";
import { useConfig } from "../contexts/ConfigContext";
import * as types from "../types";

export function useRBACSearch() {
  const config = useConfig();
  const [subjectType, setSubjectType] = useState<types.RBACSubjectType>(`user`);
  const [searchTerm, setSearchTerm] = useState<string>(``);
  const [members, setMembers] = useState<types.Member[]>([]);
  const [loading, setLoading] = useState<boolean>(false);
  const [hasInteracted, setHasInteracted] = useState<boolean>(false);
  const debounceTimerRef = useRef<number | null>(null);

  useEffect(() => {
    if (!hasInteracted) {
      return;
    }

    setMembers([]);

    if (debounceTimerRef.current !== null) {
      clearTimeout(debounceTimerRef.current);
    }

    debounceTimerRef.current = window.setTimeout(() => {
      void fetchMembers(subjectType, searchTerm);
    }, 300);

    return () => {
      if (debounceTimerRef.current !== null) {
        clearTimeout(debounceTimerRef.current);
      }
    };
  }, [subjectType, searchTerm, hasInteracted]);

  const fetchMembers = async (type: types.RBACSubjectType, search: string) => {
    setLoading(true);
    try {
      const url =
        type === `user`
          ? config.apiUrls.usersList
          : type === `group`
            ? config.apiUrls.groupsList
            : config.apiUrls.serviceAccountsList;

      const response = await url.replace({ __SEARCH__: search }).call();

      if (response.error) {
        console.error(`Failed to fetch members:`, response.error);
        setMembers([]);
      } else {
        setMembers(response.data?.members || []);
      }
    } catch (error) {
      console.error(`Error fetching members:`, error);
      setMembers([]);
    } finally {
      setLoading(false);
    }
  };

  const handleInteraction = () => {
    if (!hasInteracted) {
      setHasInteracted(true);
      setLoading(true);
    }
  };

  const handleTypeChange = (newType: types.RBACSubjectType) => {
    setSubjectType(newType);
    setMembers([]);
    setSearchTerm(``);
    setHasInteracted(false);
  };

  return {
    members,
    loading,
    searchTerm,
    setSearchTerm,
    subjectType,
    setSubjectType: handleTypeChange,
    handleInteraction,
    hasInteracted,
  };
}
