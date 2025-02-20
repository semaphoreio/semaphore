import { h } from "preact";

interface DuplicateWarningProps {
  connectedProjects: Array<{
    name: string;
    url: string;
  }>;
  onDuplicateClick: () => void;
}

export const DuplicateWarning = ({ connectedProjects, onDuplicateClick }: DuplicateWarningProps) => {
  return (
    <div className="bg-washed-yellow pa3 mt3 shadow-1 br2">
      <p className="mb0">You&apos;ve already connected this repo to Semaphore before. Jump to connected project(s):</p>
      <ul className="mb3">
        {connectedProjects.map((project) => (
          <li key={project.url}>
            <a href={project.url}>{project.name}</a>
          </li>
        ))}
      </ul>

      <p className="mb3 pt2 bt b--black-10">
        In case you want to make a duplicate project, go ahead and can set up this repo again. 
        Every time you push to the repo, Semaphore will run all connected projects.
      </p>
      <button onClick={onDuplicateClick} className="btn btn-secondary">
        Make a duplicate project
      </button>
    </div>
  );
};
