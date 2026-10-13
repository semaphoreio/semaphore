import { FunctionComponent } from "preact";
import { useEffect, useState } from "preact/hooks";

import { Contract } from "./studies/Contract";

export interface Study {
  id: string;
  title: string;
  component: FunctionComponent;
}

export const STUDIES: Study[] = [
  { id: `contract`, title: `Contract v0`, component: Contract },
];

export const studyFromHash = (hash: string): Study => {
  const id = hash.replace(/^#/, ``).split(`?`)[0];

  return STUDIES.find((study) => study.id === id) ?? STUDIES[0];
};

export const App = () => {
  const [study, setStudy] = useState(studyFromHash(window.location.hash));

  useEffect(() => {
    const followHash = () => setStudy(studyFromHash(window.location.hash));

    window.addEventListener(`hashchange`, followHash);

    return () => window.removeEventListener(`hashchange`, followHash);
  }, []);

  const StudyBody = study.component;

  return (
    <div>
      <div className="flex items-center justify-between bb b--black-15 pb2 mb3">
        <h1 className="f4 lh-title mb0">Design book</h1>
        <nav className="flex items-center">
          {STUDIES.map((entry) => (
            <a
              key={entry.id}
              href={`#${entry.id}`}
              className={`link ml2 ph2 pv1 br2 ${
                entry.id === study.id ? `bg-dark-gray white` : `gray hover-bg-washed-gray`
              }`}
            >
              {entry.title}
            </a>
          ))}
        </nav>
      </div>
      <StudyBody/>
    </div>
  );
};
