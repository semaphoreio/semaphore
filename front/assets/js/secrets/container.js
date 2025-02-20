import $ from 'jquery'
import { SecretsList } from './secret_details'
import { Pagination } from './pagination'

export class Container {
  constructor(options) {
    this.component = document.getElementById(options.selector);
    this.secrets = options.data;
    this.editable = options.editable;
    this.projectName = options.projectName;
    this.list = new SecretsList({
      selector: this.component,
      secrets: options.data,
      canManageSecrets: options.canManageSecrets,
      editable: options.editable,
      projectName: options.projectName,
      onlyButtonsOnSummary: options.onlyButtonsOnSummary
    });

    if (options.nextPageUrl != "") {
        this.pagination = new Pagination({
          nextPageUrl: options.nextPageUrl,
          onNewItems: this.loadMoreSecrets.bind(this),
        });
    }

    if (options.useToggleButton) {
      this.detailsOpened = false;
      this.toggleBtn = $(".toggle-btn")
      this.toggleBtn.on("click", this.handleToggleBtn.bind(this))
    }

    this.list.render();
  }

  loadMoreSecrets(newSecrets) {
    this.list.add(newSecrets);
    this.detailsOpened = false;
  }

  handleToggleBtn(e) {
    e.preventDefault();
    this.detailsOpened = !this.detailsOpened;
    this.toggleDetails(this.detailsOpened)
  }

  toggleDetails(open) {
    $("details").each(function(i, detail) {
      if (open) {
        detail.setAttribute('open', true)
      } else {
        detail.removeAttribute('open')
      }
    })

    this.toggleBtn.text(open ? "Collapse all" : "Expand all")
  }
}