import { expect } from "chai";
import { describe, test } from "mocha";

import { STUDIES, studyFromHash } from "./App";

describe(`design book study registry`, () => {
  test(`registers at least one study`, () => {
    expect(STUDIES.length).to.be.greaterThan(0);
  });

  test(`gives every study a unique id, a title and a component`, () => {
    const ids = STUDIES.map((study) => study.id);

    expect(new Set(ids).size).to.eq(STUDIES.length);

    STUDIES.forEach((study) => {
      expect(study.id).to.not.eq(``);
      expect(study.title).to.not.eq(``);
      expect(study.component).to.be.a(`function`);
    });
  });
});

describe(`studyFromHash`, () => {
  test(`resolves a study from its hash`, () => {
    const study = STUDIES[0];

    expect(studyFromHash(`#${study.id}`).id).to.eq(study.id);
  });

  test(`resolves a study from a hash without the leading marker`, () => {
    const study = STUDIES[0];

    expect(studyFromHash(study.id).id).to.eq(study.id);
  });

  test(`falls back to the first study for an empty hash`, () => {
    expect(studyFromHash(``).id).to.eq(STUDIES[0].id);
  });

  test(`falls back to the first study for an unknown hash`, () => {
    expect(studyFromHash(`#no-such-study`).id).to.eq(STUDIES[0].id);
  });

  test(`ignores a query suffix after the study id`, () => {
    const study = STUDIES[STUDIES.length - 1];

    expect(studyFromHash(`#${study.id}?regions=3&spot=off`).id).to.eq(study.id);
  });
});
