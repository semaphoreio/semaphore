export enum Origin {
  Unknown = 0,
  Member = 1,
  ActiveMember = 2,
  GithubMember = 3,
  BitbucketMember = 3,
}

export class Seat {
  id: string;
  origin: Origin;
  displayName: string;
  icon: string;
  iconWidth: number;
  iconHeight: number;

  originName(): string {
    switch(this.origin) {
      case Origin.Member:
        return `Member`;
      case Origin.GithubMember:
        return `Non-member`;
      case Origin.BitbucketMember:
        return `Non-member`;
      default:
        return `Unknown`;
    }
  }

  setMember() {
    this.origin = Origin.Member;
    this.icon = `images/semaphore-logo-sign-black.svg`;
  }

  setGithubMember() {
    this.origin = Origin.GithubMember;
    this.icon = `images/icn-github.svg`;
  }

  setBitbucketMember() {
    this.origin = Origin.BitbucketMember;
    this.icon = `images/icn-bitbucket.svg`;
  }

  static fromJSON(json: any): Seat {
    const seat = new Seat();

    seat.id = json.user_id as string;
    seat.displayName = json.display_name as string;
    seat.origin = Origin.Unknown;
    seat.iconHeight = 18;
    seat.iconWidth = 18;

    switch(json.origin as string) {
      case `semaphore`:
        seat.setMember();
        seat.iconWidth = 26;
        break;
      case `github`:
        seat.setGithubMember();
        break;
      case `bitbucket`:
        seat.setBitbucketMember();
        break;
    }

    return seat;
  }
}
