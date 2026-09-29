import { escapeHtml } from "../escape_html"

// The row goes into insertAdjacentHTML, and both the user and the assets path are read
// at runtime - the user from autocomplete results, the path out of a meta tag - so every
// interpolation is escaped, in attributes as well as in text.
export function projectUserRowMarkup(user, assetsPath) {
  return `
    <div id="${escapeHtml(user.id)}" class="flex items-center justify-between bg-white shadow-1 mv1 mh1 ph3 pv2 br3">
      <div class="flex items-center">
        ${user.subject_type === "service_account"
          ? `<div class="w2 h2 br-100 mr2 ba b--black-50 flex items-center justify-center bg-light-gray"><span class="material-symbols-outlined f6 gray">smart_toy</span></div>`
          : user.has_avatar
            ? `<img src="${escapeHtml(user.avatar)}" class="w2 h2 br-100 mr2 ba b--black-50">`
            : `<img src="${escapeHtml(assetsPath)}/images/org-${escapeHtml(user.name.charAt(0).toLowerCase())}.svg" class="bg-washed-gray w2 h2 br-100 mr2 ba b--black-50">`
        }
        <div class="flex items-center">
          <div class="b">${escapeHtml(user.name)}</div>
          ${user.github_login ? `<div class="ml2 f6 gray">@${escapeHtml(user.github_login)}</div>` : `` }
        </div>
      </div>
      <button class="btn btn-secondary">×</button>
    </div>
    `
}
