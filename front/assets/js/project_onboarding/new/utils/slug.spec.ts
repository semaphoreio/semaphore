import { expect } from "chai";
import { describe, it } from "mocha";
import { parseRepositorySlug, extractRepositorySearchTerm } from "./slug";

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

describe(`extractRepositorySearchTerm`, () => {
  it(`returns a bare owner/repository slug unchanged`, () => {
    expect(extractRepositorySearchTerm(`octo/repo`)).to.eq(`octo/repo`);
  });

  it(`passes plain search text through`, () => {
    expect(extractRepositorySearchTerm(`repo`)).to.eq(`repo`);
  });

  it(`extracts owner/repo from an https web URL`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo`)).to.eq(`octo/repo`);
  });

  it(`strips a trailing .git`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo.git`)).to.eq(`octo/repo`);
  });

  it(`ignores trailing slash, query and fragment`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo/?tab=readme#x`)).to.eq(
      `octo/repo`
    );
  });

  it(`ignores extra path segments after owner/repo`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo/tree/main`)).to.eq(
      `octo/repo`
    );
  });

  it(`handles git:// URLs`, () => {
    expect(extractRepositorySearchTerm(`git://github.com/octo/repo.git`)).to.eq(`octo/repo`);
  });

  it(`handles ssh:// URLs`, () => {
    expect(extractRepositorySearchTerm(`ssh://git@github.com/octo/repo.git`)).to.eq(`octo/repo`);
  });

  it(`handles scp-like git@host:owner/repo remotes`, () => {
    expect(extractRepositorySearchTerm(`git@github.com:octo/repo.git`)).to.eq(`octo/repo`);
  });

  it(`handles bitbucket and gitlab hosts`, () => {
    expect(extractRepositorySearchTerm(`https://bitbucket.org/team/svc`)).to.eq(`team/svc`);
    expect(extractRepositorySearchTerm(`git@gitlab.com:group/app.git`)).to.eq(`group/app`);
  });

  it(`trims surrounding whitespace`, () => {
    expect(extractRepositorySearchTerm(`  https://github.com/octo/repo  `)).to.eq(`octo/repo`);
  });

  it(`returns an empty string for empty input`, () => {
    expect(extractRepositorySearchTerm(``)).to.eq(``);
  });
});
