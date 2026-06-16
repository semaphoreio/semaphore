import { expect } from "chai";
import { describe, it } from "mocha";
import { parseRepositorySlug } from "./slug";

describe(`parseRepositorySlug`, () => {
  it(`accepts an owner/repository slug`, () => {
    expect(parseRepositorySlug(`renderedtext/guard`)).to.eq(`renderedtext/guard`);
  });

  it(`accepts dots, dashes and underscores in the repository name`, () => {
    expect(parseRepositorySlug(`octo-org/my_repo.js`)).to.eq(`octo-org/my_repo.js`);
  });

  it(`trims surrounding whitespace`, () => {
    expect(parseRepositorySlug(`  octo/repo  `)).to.eq(`octo/repo`);
  });

  it(`rejects a bare word`, () => {
    expect(parseRepositorySlug(`not_listed`)).to.be.null;
  });

  it(`rejects a trailing slash`, () => {
    expect(parseRepositorySlug(`octo/`)).to.be.null;
  });

  it(`rejects extra path segments`, () => {
    expect(parseRepositorySlug(`octo/repo/extra`)).to.be.null;
  });

  it(`rejects inner spaces`, () => {
    expect(parseRepositorySlug(`octo/my repo`)).to.be.null;
  });

  it(`rejects full URLs`, () => {
    expect(parseRepositorySlug(`https://github.com/octo/repo`)).to.be.null;
  });
});
