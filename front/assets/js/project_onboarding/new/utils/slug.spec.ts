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

  it(`rejects an owner longer than 39 characters`, () => {
    expect(parseRepositorySlug(`${`a`.repeat(40)}/repo`)).to.be.null;
  });

  it(`rejects a repository longer than 100 characters`, () => {
    expect(parseRepositorySlug(`octo/${`a`.repeat(101)}`)).to.be.null;
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

describe(`extractRepositorySearchTerm (provider-aware)`, () => {
  it(`keeps the full nested-group path for a GitLab web URL`, () => {
    expect(
      extractRepositorySearchTerm(`https://gitlab.com/group/subgroup/repo`, `gitlab`)
    ).to.eq(`group/subgroup/repo`);
  });

  it(`drops GitLab "/-/" route sub-pages but keeps the project path`, () => {
    expect(
      extractRepositorySearchTerm(`https://gitlab.com/group/sub/repo/-/tree/main`, `gitlab`)
    ).to.eq(`group/sub/repo`);
  });

  it(`handles a GitLab scp-like nested remote`, () => {
    expect(
      extractRepositorySearchTerm(`git@gitlab.com:group/sub/repo.git`, `gitlab`)
    ).to.eq(`group/sub/repo`);
  });

  it(`handles a simple GitLab repository`, () => {
    expect(extractRepositorySearchTerm(`https://gitlab.com/owner/repo`, `gitlab`)).to.eq(
      `owner/repo`
    );
  });

  it(`still caps GitHub deep browse URLs at owner/repo`, () => {
    expect(
      extractRepositorySearchTerm(`https://github.com/octo/repo/tree/main`, `github_app`)
    ).to.eq(`octo/repo`);
  });

  it(`extracts a Bitbucket repository for the bitbucket provider`, () => {
    expect(
      extractRepositorySearchTerm(`https://bitbucket.org/team/svc`, `bitbucket`)
    ).to.eq(`team/svc`);
  });

  it(`defaults to the two-segment cap when no provider is given`, () => {
    expect(
      extractRepositorySearchTerm(`https://gitlab.com/group/subgroup/repo`)
    ).to.eq(`group/subgroup`);
  });
});

describe(`extractRepositorySearchTerm (domain validation)`, () => {
  it(`does not treat a non-provider web URL as a repo`, () => {
    const input = `https://www.randomdomain.com/foo/bar`;
    const result = extractRepositorySearchTerm(input, `github_app`);

    expect(result).to.eq(input);
    expect(parseRepositorySlug(result)).to.be.null;
  });

  it(`does not treat a non-provider scp remote as a repo`, () => {
    const input = `git@randomdomain.com:foo/bar.git`;
    expect(extractRepositorySearchTerm(input, `github_app`)).to.eq(input);
  });

  it(`rejects a URL whose host belongs to a different provider`, () => {
    const input = `https://gitlab.com/group/repo`;
    expect(extractRepositorySearchTerm(input, `github_app`)).to.eq(input);
  });

  it(`rejects a GitHub Enterprise / custom host`, () => {
    const input = `https://github.acme.com/octo/repo`;
    expect(extractRepositorySearchTerm(input, `github_app`)).to.eq(input);
  });

  it(`accepts the provider's own host`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo`, `github_app`)).to.eq(
      `octo/repo`
    );
  });

  it(`strips port and userinfo before checking the host`, () => {
    expect(extractRepositorySearchTerm(`https://github.com:443/octo/repo`, `github_app`)).to.eq(
      `octo/repo`
    );
    expect(extractRepositorySearchTerm(`ssh://git@github.com/octo/repo.git`, `github_app`)).to.eq(
      `octo/repo`
    );
  });

  it(`accepts any known provider host when no provider is given`, () => {
    expect(extractRepositorySearchTerm(`https://github.com/octo/repo`)).to.eq(`octo/repo`);
  });
});
