
import { useEffect, useContext, useState, useRef, useMemo } from "preact/hooks";
import * as stores from "../stores";
import * as toolbox from "js/toolbox";
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
  const inputRef = useRef<HTMLInputElement>(null);
  const dropdownRef = useRef<HTMLDivElement>(null);

  const filteredRepositories = useMemo(
    () =>
      repositories.filter((repo) => {
        const searchFields = [repo.full_name, repo.name, repo.url];
        return searchFields.some((field) =>
          field?.toLowerCase().includes(searchQuery.toLowerCase()),
        );
      }),
    [repositories, searchQuery],
  );

  const loadRepositories = async (url: string) => {
    if (!url || isLoading) return;
    setIsLoading(true);

    try {
      const response = await fetch(url);
      const json: ApiResponse = await response.json();
      const repos = json.repos;

      setRepositories(prev => [...prev, ... repos]);
      setNextPageToken(json.next_page_token || null);

      // If we have few filtered results after search, automatically load more
      if (json.next_page_token && filteredRepositories.length < 5) {
        const nextUrl = `${props.repositoriesUrl}&page_token=${json.next_page_token}`;
        void loadRepositories(nextUrl);
      }
    } catch (error) {
      Notice.error(`Error loading repositories: ${String(error)}`);
    } finally {
      setIsLoading(false);
    }
  };

  const handleSearch = (event: Event) => {
    const target = event.target as HTMLInputElement;
    setSearchQuery(target.value);
  };

  useEffect(() => {
    if (props.repositoriesUrl) {
      void loadRepositories(props.repositoriesUrl);
    }
  }, [props.repositoriesUrl]);

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
      ),
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
                      <span>{highlightMatch(repo.full_name, searchQuery)}</span>
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
                        ? highlightMatch(repo.description, searchQuery)
                        : ``}
                    </p>
                    <p className="f4 measure black-60 mb0">
                      {repo.url ? highlightMatch(repo.url, searchQuery) : ``}
                    </p>
                  </div>
                </div>
              ))}

              {isLoading && (
                <div className="flex items-center justify-center pa3">
                  <toolbox.Asset
                    path="images/spinner-2.svg"
                    className="mr2"
                    alt="spinner"
                    style={{ width: `20px`, height: `20px` }}
                  />
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
              configState.githubAppInstallationUrl && (
              <div
                id="new-project-repositories-button"
                className="dn"
                style={{ display: `block` }}
              >
                <a
                  href={configState.githubAppInstallationUrl}
                  target="_blank"
                  className="link db dark-gray pv3 ph2 bt b--black-10 hide-child hover-bg-row-highlight"
                  rel="noreferrer"
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
          </div>
        )}
      </div>
    </div>
  );
};
