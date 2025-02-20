export class Favicon {
  static replace(state) {
    let statuses = new Map([
      ['running', 'favicon-running'],
      ['passed',  'favicon-passed'],
      ['failed',  'favicon-failed'],
      ['stopping', 'favicon-stopped'],
      ['stopped', 'favicon-stopped'],
      ['canceled', 'favicon-not-completed'],
      ['pending', 'favicon-queued'],
    ])
    let base = "favicon"

    document.querySelectorAll(".js-site-favicon").forEach(function(link) {
      let href = link.href
      link.href = href.replace(/favicon[-a-z]*/, statuses.get(state) || base)
    })
  }
}

