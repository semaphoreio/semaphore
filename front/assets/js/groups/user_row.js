import { escapeHtml } from "../escape_html"

// The row goes into insertAdjacentHTML and the user comes from autocomplete results, so
// every interpolation is escaped, in attributes as well as in text.
export function groupUserRowMarkup(user) {
  return `
    <div id="${escapeHtml(user.id)}" class="flex items-center justify-between bg-white shadow-1 mv1 mh1 ph3 pv2 br3">
      <div class="flex items-center">
        ${user.avatar
          ? `<img src="${escapeHtml(user.avatar)}" class="w2 h2 br-100 mr2 ba b--black-50">`
          : `<div class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50"></div>`
        }
        <div class="flex items-center">
          <div class="b">${escapeHtml(user.name)}</div>
          ${user.github_login ? `<div class="ml2 f6 gray">@${escapeHtml(user.github_login)}</div>` : `` }
        </div>
      </div>
      <button name="rmv_btn" class="btn btn-secondary">×</button>
    </div>
    `
}
