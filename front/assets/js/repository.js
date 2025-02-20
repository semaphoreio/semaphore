import $ from "jquery";
import Mustache from 'mustache'
import { Notice } from "./notice"

window.Notice = Notice;

export var Repository = {
  init: function() {
    Notice.init();
    this.options = {
      disabled_template: null,
      enabled_template: null,
      duplicate_template: null,
      working: false,
      refreshing: false,
      repositories: $("#repositories"),
      next_page_token: null,
      check_url: null,
    }

    if(document.getElementById("disabled-repository")) {
      this.options.disabled_template = document.getElementById("disabled-repository").innerHTML;
      this.options.enabled_template = document.getElementById("enabled-repository").innerHTML;
      this.options.duplicate_template = document.getElementById("duplicate-repository").innerHTML;

      $("#x-filter-repositories").on("keyup", this.handleFilterRepositories.bind(this));
      $("#repositories").on("click", "submit", this.createProject.bind(this));

      this.tick();
    }
  },

  handleFilterRepositories: function(event) {
    var filter = event.target.value.toUpperCase();
    this.filterRepositories(filter);
  },

  filterRepositories: function(filter) {
    var repos = document.getElementById('repositories');

    for (let item of repos.getElementsByClassName("x-repository-box")) {
      this.filterRepository(filter, item);
    }
  },

  filterRepository: function(filter, item) {
    if(item.dataset.name.toUpperCase().indexOf(filter) > -1) {
      item.classList.toggle("dn", false);
    } else {
      item.classList.toggle("dn", true);
    }

    return item
  },

  createProject: function(event) {
    event.preventDefault();

    if (this.options.working) { return true; }
    this.options.working = true;

    const form = event.currentTarget.closest('form')
    const body = new FormData( form );

    fetch(form.action, {
      method: 'POST',
      body: body
    })
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((res) => {
      if(res.error) {
        throw new Error(res.error);
      } else {
        return res;
      }
    })
    .then((data) => {
      if(data.redirect_to != undefined) {
        window.location = data.redirect_to;
      } else {
        this.renderWarrningMessage(event.currentTarget, data.projects)
      }
    })
    .catch(function(reason) {
      Notice.error(reason)
    })
    .finally(() => {
      this.options.working = false;
    })
  },

  renderWarrningMessage: function(target, projects) {
    const data = {
      projects: projects,
      name: target.dataset.name,
      full_name: target.dataset.full_name,
      description: target.dataset.description,
      url: target.dataset.url
    }

    const html = Mustache.render(this.options.duplicate_template, data);
    target.closest(".x-repository-box").innerHTML = html
  },

  tick: function(){
    if(this.isFinal()) {
      return false
    }

    this.options.refreshing = true;
    this.fetch();
  },
  isFinal: function() {
    return this.options.next_page_token == "";
  },
  fetch: function() {
    window.requestAnimationFrame(function() {
      this.fetch_retry(this.fetchUrl(), {credentials: 'same-origin'}, 5)
      .then(this.parseJson.bind(this))
      .then(this.parseErrors)
      .then(this.updateOptions.bind(this))
      .then(this.displayRepositories.bind(this))
      .then(this.displayFinal.bind(this))
      .then(this.anotherFetch.bind(this))
      .catch(
        (reason) => {
          console.log(reason);
        });
    }.bind(this));
  },
  parseErrors: function(data) {
    if(data.hasOwnProperty('error')) {
      throw new Error(data.error);
    } else {
      return data;
    }
  },
  fetchUrl: function() {
    let url, next_page_token;
    url = this.options.repositories.data('repositories-url');
    next_page_token = this.options.next_page_token;

    if(url.includes("?")) {
      url = url + "&page_token=" + next_page_token;
    } else {
      url = url + "?page_token=" + next_page_token;
    }

    return url;
  },
  fetch_retry: function(url, options, n) {
    return fetch(url, options).catch(function(error) {
      if (n === 1) throw error;
      return this.fetch_retry(url, options, n - 1);
    });
  },
  isJsonResponse: function(response) {
    var contentType = response.headers.get("content-type");
    return contentType && contentType.includes("application/json")
  },
  parseJson: function(response) {
    if (this.isJsonResponse(response)) {
      return response.json();
    } else {
      {}
    }
  },
  anotherFetch: function() {
    if(!this.isFinal()) {
      setTimeout(this.tick.bind(this), 500);
    } else {
      this.options.refreshing = false;
    }
  },
  updateOptions: function(data) {
    this.options.next_page_token = data.next_page_token;

    return data;
  },
  displayFinal: function() {
    if(this.isFinal()) {
      $("#new-project-repositories-placeholder").hide();
      $("#new-project-repositories-button").show();
    }
  },
  displayRepositories: function(repositories) {
    repositories.repos.forEach(function(repository) {
      let html;
      if(repository.addable) {
        html = Mustache.render(this.options.enabled_template, repository);
      } else {
        html = Mustache.render(this.options.disabled_template, repository);
      }

      $("#new-project-repositories-placeholder").hide();
      $("#new-project-repositories-button").show();

      let filter = $("#x-filter-repositories")[0].value.toUpperCase()
      html = this.filterRepository(filter, $(html)[0])

      this.options.repositories.append(html);
    }.bind(this))
  }
};
