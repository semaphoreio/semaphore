
import { useEffect, useContext, useState, useRef, useMemo } from "preact/hooks";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
import { parseRepositorySlug, extractRepositorySearchTerm } from "../utils/slug";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import { Notice } from "js/notice";

interface Repository {
  url: string;
  name: string;
  full_name: string;
  description: string;
  addable: boolean;
  connected_projects?: Array<{
    name: string;
    url: string;
  }>;
}

interface ApiResponse {
  repos: Repository[];
  next_page_token?: string;
}

interface ApiErrorResponse {
  error?: string;
  message?: string;
}

interface RefreshResponse {
  state: string;
  message?: string;
  retry_after?: number;
}

// Refreshed repositories are synced by background workers; give them a
// moment before re-fetching the list.
const REFRESH_RELOAD_DELAY_MS = 15000;

interface RepositorySelectorProps {
  repositoriesUrl: string;
  githubInstallUrl?: string;
}

export const RepositorySelector = (props: RepositorySelectorProps) => {
  const { selectRepository } = useContext(stores.Create.Repository.Context);
  const { state: providerState } = useContext(stores.Create.Provider.Context);
  const configState = useContext(stores.Create.Config.Context);
  const { state: repoState } = useContext(stores.Create.Repository.Context);
  const [isLoading, setIsLoading] = useState(false);
  const [repositories, setRepositories] = useState<Repository[]>([]);
  const [nextPageToken, setNextPageToken] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState(``);
  const [selectedRepo, setSelectedRepo] = useState<Repository | null>(null);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [cooldownLeft, setCooldownLeft] = useState(0);
  const [manualSlug, setManualSlug] = useState(``);
  const inputRef = useRef<HTMLInputElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);
  const reloadTimeoutRef = useRef<number | null>(null);

  // When the user pastes a repository web/git URL, search by its owner/repo
  // slug only; plain typing passes through unchanged.
  const searchTerm = extractRepositorySearchTerm(searchQuery);
  const slugCandidate = parseRepositorySlug(searchTerm);
  const manualSlugValid = parseRepositorySlug(manualSlug);

  const filteredRepositories = useMemo(
    () =>
      repositories.filter((repo) => {
        const searchFields = [repo.full_name, repo.name, repo.url];
        return searchFields.some((field) =>
          field?.toLowerCase().includes(searchTerm.toLowerCase())
        );
      }),
    [repositories, searchTerm]
  );

  const parseErrorMessage = (payload: unknown): string | null => {
    if (!payload || typeof payload !== `object`) return null;

    const message =
      `message` in payload && typeof payload.message === `string` ? payload.message : null;
    const code = `error` in payload && typeof payload.error === `string` ? payload.error : null;

    if (message && code) return `${message} (${code})`;
    if (message) return message;
    if (code) return code;

    return null;
  };

  const loadRepositories = async (url: string) => {
    if (!url || isLoading) return;
    setIsLoading(true);

    try {
      const response = await fetch(url);
      const contentType = response.headers.get(`content-type`) || ``;
      const isJson = contentType.includes(`application/json`);

      if (!isJson) {
        const responseBody = await response.text();
        const responsePreview = responseBody.replace(/\s+/g, ` `).trim().slice(0, 200);
        const details = responsePreview ? `: ${responsePreview}` : ``;

        throw new Error(`Failed to load repositories (HTTP ${response.status})${details}`);
      }

      const payload: ApiResponse | ApiErrorResponse = await response.json();

      if (!response.ok) {
        const message = parseErrorMessage(payload);
        throw new Error(message || `Failed to load repositories (HTTP ${response.status})`);
      }

      const json = payload as ApiResponse;
      if (!json || !Array.isArray(json.repos)) {
        const message = parseErrorMessage(payload);
        throw new Error(message || `Failed to load repositories: invalid response payload`);
      }

      const repos = json.repos;

      setRepositories(prev => [...prev, ... repos]);
      setNextPageToken(json.next_page_token || null);

      // If we have few filtered results after search, automatically load more
      if (json.next_page_token && filteredRepositories.length < 5) {
        const nextUrl = `${props.repositoriesUrl}&page_token=${json.next_page_token}`;
        void loadRepositories(nextUrl);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      Notice.error(`Error loading repositories: ${message}`);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = (event: Event) => {
    const target = event.target as HTMLInputElement;
    setSearchQuery(target.value);
  };

  const reloadRepositories = () => {
    setRepositories([]);
    setNextPageToken(null);
    void loadRepositories(props.repositoriesUrl);
  };

  const startCooldown = () => {
    setCooldownLeft(configState.repositoryRefreshCooldown ?? 60);
  };

  const requestRefresh = async (slug?: string) => {
    if (!configState.refreshRepositoriesUrl || isRefreshing) return;
    setIsRefreshing(true);

    try {
      const { data, error, status } = await toolbox.APIRequest.post<RefreshResponse>(
        configState.refreshRepositoriesUrl,
        {
          integration_type: providerState.selectedProvider?.type,
          repository_slug: slug ?? ``,
        }
      );

      if (status === 429) {
        setCooldownLeft(data?.retry_after ?? configState.repositoryRefreshCooldown ?? 60);
        Notice.notice(data?.message || `Refresh was requested recently. Try again in a minute.`);
        return;
      }

      switch (data?.state) {
        case `started`:
          Notice.notice(data.message || `Repository sync started.`);
          if (!slug) startCooldown();
          if (reloadTimeoutRef.current !== null) window.clearTimeout(reloadTimeoutRef.current);
          reloadTimeoutRef.current = window.setTimeout(reloadRepositories, REFRESH_RELOAD_DELAY_MS);
          break;
        case `already_running`:
          Notice.notice(data.message || `A repository sync is already running.`);
          if (!slug) startCooldown();
          break;
        case `done`:
          if (slug) {
            reloadRepositories();
          }
          break;
        default:
          Notice.error(data?.message || error || `Could not refresh repositories.`);
      }
    } finally {
      setIsRefreshing(false);
    }
  };

  const submitManualSlug = () => {
    const slug = parseRepositorySlug(manualSlug);
    if (!slug || isRefreshing) return;
    void requestRefresh(slug);
  };

  useEffect(() => {
    if (props.repositoriesUrl) {
      void loadRepositories(props.repositoriesUrl);
    }
  }, [props.repositoriesUrl]);

  useEffect(() => {
    if (cooldownLeft <= 0) return;

    const interval = window.setInterval(() => {
      setCooldownLeft((left) => (left > 1 ? left - 1 : 0));
    }, 1000);

    return () => window.clearInterval(interval);
  }, [cooldownLeft > 0]);

  useEffect(() => {
    return () => {
      if (reloadTimeoutRef.current !== null) window.clearTimeout(reloadTimeoutRef.current);
    };
  }, []);

  useEffect(() => {
    if (filteredRepositories.length > 0 && hoveredIndex === null) {
      setHoveredIndex(0);
    } else if (filteredRepositories.length === 0) {
      setHoveredIndex(null);
    }
  }, [filteredRepositories]);

  const handleSelectRepository = (repo: Repository) => {
    setSelectedRepo(repo);
    selectRepository(repo);
    if (inputRef.current) {
      inputRef.current.disabled = true;
    }
  };

  const handleClear = () => {
    setSelectedRepo(null);
    selectRepository(null);
    if (inputRef.current) {
      inputRef.current.disabled = false;
    }
  };

  const getItemStyle = (index: number) => {
    if (hoveredIndex === index) {
      return {
        backgroundColor: `#f5fafd`,
        color: `#495c68`,
      };
    }
    return {};
  };

  const highlightMatch = (text: string, query: string) => {
    if (!query || query.length > 50) return text; // Limit query length for safety

    const escapedQuery = query.replace(/[.*+?^${}()|[\]\\]/g, `\\$&`);
    const regex = new RegExp(`(${escapedQuery})`, `gi`);
    const parts = text.split(regex);

    return parts.map((part, i) =>
      regex.test(part) ? ( // njsscan-ignore: regex_dos
        <mark key={i} style={{ backgroundColor: `rgba(125, 168, 208, 0.2)` }}>
          {part}
        </mark>
      ) : (
        part
      )
    );
  };

  const handleFocus = () => {
    if (filteredRepositories.length > 0) {
      setHoveredIndex(0);
    }
  };

  const handleScroll = (event: Event) => {
    const target = event.target as HTMLDivElement;
    if (
      !isLoading &&
      nextPageToken &&
      target.scrollHeight - target.scrollTop <= target.clientHeight + 100
    ) {
      void loadRepositories(`${props.repositoriesUrl}&page_token=${nextPageToken}`);
    }
  };

  const handleKeyDown = (event: KeyboardEvent) => {
    if (!filteredRepositories.length) return;

    switch (event.key) {
      case `ArrowDown`:
        event.preventDefault();
        setHoveredIndex((prev) => {
          if (prev === null) return 0;
          return prev < filteredRepositories.length - 1 ? prev + 1 : prev;
        });
        break;
      case `ArrowUp`:
        event.preventDefault();
        setHoveredIndex((prev) => {
          if (prev === null) return 0;
          return prev > 0 ? prev - 1 : prev;
        });
        break;
      case `Enter`:
        event.preventDefault();
        if (hoveredIndex !== null) {
          handleSelectRepository(filteredRepositories[hoveredIndex]);
        }
        break;
    }
  };

  return (
    <div>
      <div className="relative">
        <input
          ref={inputRef}
          type="text"
          className="w-100 pa2 shadow-1 br3 br--top ba b--lightest-gray"
          placeholder="Search repositories..."
          value={selectedRepo ? selectedRepo.full_name : searchQuery}
          onInput={handleSearch}
          onFocus={handleFocus}
          onKeyDown={handleKeyDown}
          disabled={!!selectedRepo}
        />
        {selectedRepo && (
          <button
            onClick={handleClear}
            className="absolute right-1 pa2 pr0 bg-transparent bn pointer"
            aria-label="Clear selection"
            style={{ marginTop: `2px` }}
            disabled={repoState.isCreatingProject || repoState.projectCreationStatus.isComplete}
          >
            ×
          </button>
        )}
      </div>
      <div className="bg-white shadow-1 br3 br--bottom" style="overflow: hidden;">
        {!selectedRepo && (
          <div
            ref={dropdownRef}
            className="bg-white shadow-1 br2"
          >
            <div
              className="br2"
              style={{
                maxHeight: `300px`,
                overflowY: `auto`,
                scrollBehavior: `smooth`,
                overflowX: `hidden`,
              }}
              onScroll={handleScroll}
            >
              {filteredRepositories.map((repo, index) => (
                <div
                  key={repo.full_name}
                  className={`flex option pv1 ph3 ${repo.addable ? `pointer` : ``}`}
                  data-selectable=""
                  data-value={repo.full_name}
                  role="option"
                  id={`repo-search-opt-${index + 1}`}
                  aria-selected={hoveredIndex === index}
                  onMouseEnter={() => repo.addable && setHoveredIndex(index)}
                  onMouseLeave={() => repo.addable && setHoveredIndex(null)}
                  onClick={() => repo.addable && handleSelectRepository(repo)}
                  style={getItemStyle(index)}
                >
                  <div className="flex-shrink-0 mt1 mr2">
                    <toolbox.Asset
                      path="images/icn-repository.svg"
                      alt="repository"
                    />
                  </div>
                  <div className="w-100">
                    <h3 className="f4 mb0 flex items-center justify-between">
                      <span>{highlightMatch(repo.full_name, searchTerm)}</span>
                      <span className="f6 fw5">
                        {repo.addable ? (
                          <>
                            <span className="dn di-m child green mr1">Choose</span>
                            <span className="inline-flex items-center justify-center w1 h1 bg-green white br-100 ba b--green bw1">
                              →
                            </span>
                          </>
                        ) : (
                          <>
                            <span className="dn di-m child gray mr1">You need admin access on GitHub</span>
                            <span className="inline-flex items-center justify-center w1 h1 bg-gray white br-100 ba b--gray bw1">
                              ✗
                            </span>
                          </>
                        )}
                      </span>
                    </h3>
                    <p className="f4 measure black-60 mb0">
                      {repo.description
                        ? highlightMatch(repo.description, searchTerm)
                        : ``}
                    </p>
                    <p className="f4 measure black-60 mb0">
                      {repo.url ? highlightMatch(repo.url, searchTerm) : ``}
                    </p>
                  </div>
                </div>
              ))}

              {isLoading && (
                <div className="flex items-center justify-center pa3">
                  <toolbox.Asset path="images/spinner-2.svg" className="mr2" alt="spinner" style={{ width: `20px`, height: `20px` }}/>
                  <span className="f5 black-60">Loading repositories...</span>
                </div>
              )}
            </div>
            {filteredRepositories.length === 0 && !isLoading && (
              <div className="mt3 pl3">
                <p className="f5 black-70">No repositories found.</p>
              </div>
            )}
            {providerState.selectedProvider?.type === `github_app` &&
              configState.refreshRepositoriesUrl &&
              !isLoading &&
              filteredRepositories.length === 0 &&
              slugCandidate && (
              <div
                className="flex option pv2 ph3 pointer bt b--black-10"
                role="option"
                onClick={() => void requestRefresh(slugCandidate)}
              >
                <div className="flex-shrink-0 mt1 mr2">
                  <toolbox.Asset
                    path="images/icn-repository.svg"
                    alt="repository"
                  />
                </div>
                <div className="w-100">
                  <h3 className="f4 mb0">
                      Fetch {slugCandidate} from GitHub
                  </h3>
                  <p className="f4 measure black-60 mb0">
                      Sync only this repository&apos;s data from GitHub
                  </p>
                </div>
                {isRefreshing && (
                  <toolbox.Asset path="images/spinner-2.svg" className="mr2" alt="spinner" style={{ width: `20px`, height: `20px` }}/>
                )}
              </div>
            )}
            {providerState.selectedProvider?.type === `github_app` &&
              configState.githubAppInstallationUrl && (
              <div id="new-project-repositories-button" className="dn" style={{ display: `block` }}>
                <a
                  href={configState.githubAppInstallationUrl}
                  target="_blank"
                  className="link db dark-gray pv3 ph2 bt b--black-10 hide-child hover-bg-row-highlight" rel="noreferrer"
                >
                  <div className="flex">
                    <div className="flex-shrink-0 mt1 mr2">
                      <toolbox.Asset
                        path="images/icn-plus-nav.svg"
                        style={{ width: `16px`, height: `16px` }}
                      />
                    </div>
                    <div className="w-100">
                      <h3 className="f4 mb0">Give access to more repositories</h3>
                      <p className="f4 measure black-60 mb0">
                          Jump to GitHub to allow access
                      </p>
                    </div>
                  </div>
                </a>
              </div>
            )}
            {providerState.selectedProvider?.type === `github_app` &&
              configState.refreshRepositoriesUrl && (
              <button
                type="button"
                className="w-100 tl bg-white db dark-gray pv3 ph2 bt b--black-10 hover-bg-row-highlight bn bt b--black-10"
                style={{ cursor: isRefreshing || cooldownLeft > 0 ? `default` : `pointer` }}
                disabled={isRefreshing || cooldownLeft > 0}
                onClick={() => void requestRefresh()}
              >
                <div className="flex">
                  <div className="flex-shrink-0 mt1 mr2">
                    <toolbox.Asset
                      path={isRefreshing ? `images/spinner-2.svg` : `images/icn-refresh.svg`}
                      style={{ width: `16px`, height: `16px` }}
                    />
                  </div>
                  <div className="w-100">
                    <h3 className="f4 mb0">
                      {cooldownLeft > 0
                        ? `Refresh available in ${cooldownLeft}s`
                        : `Refresh repository list`}
                    </h3>
                    <p className="f4 measure black-60 mb0">
                        Repository list out of date? Re-sync it from GitHub
                    </p>
                  </div>
                </div>
              </button>
            )}
            {providerState.selectedProvider?.type === `github_app` &&
              configState.refreshRepositoriesUrl && (
              <div className="pv3 ph2 bt b--black-10">
                <h3 className="f4 mb1">Repository not listed? Try refreshing it manually</h3>
                <div className="flex items-center">
                  <input
                    type="text"
                    className="form-control flex-auto ba b--black-20 br2 pa2 mr2"
                    style={{ outline: `none`, boxShadow: `none` }}
                    placeholder="organization/repository"
                    value={manualSlug}
                    onInput={(event) =>
                      setManualSlug((event.target as HTMLInputElement).value)
                    }
                    onKeyDown={(event: KeyboardEvent) => {
                      if (event.key === `Enter`) {
                        event.preventDefault();
                        submitManualSlug();
                      }
                    }}
                  />
                  <button
                    type="button"
                    className="btn btn-secondary"
                    style={{
                      cursor: !manualSlugValid || isRefreshing ? `default` : `pointer`,
                    }}
                    disabled={!manualSlugValid || isRefreshing}
                    onClick={submitManualSlug}
                  >
                    {isRefreshing ? (
                      <toolbox.Asset
                        path="images/spinner-2.svg"
                        alt="spinner"
                        style={{ width: `16px`, height: `16px` }}
                      />
                    ) : (
                      `Refresh`
                    )}
                  </button>
                </div>
                <p className="f6 black-60 mt1 mb0">
                  {manualSlug.length > 0 && !manualSlugValid
                    ? `Use the owner/repository format, e.g. organization/repository`
                    : `Paste the repository in owner/repository format to sync just that repository.`}
                </p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
};
