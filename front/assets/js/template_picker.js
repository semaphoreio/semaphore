import $ from "jquery";
import hljs from 'highlight.js/lib/highlight';
import yaml from 'highlight.js/lib/languages/yaml';
import { Notice } from "./notice"
hljs.registerLanguage('yaml', yaml);

export var TemplatePicker = {
  init: function() {
    this.templates = window.InjectedDataByBackend.Templates;

    this.showTemplate(window.InjectedDataByBackend.DefaultTemplateTitle);
    this.registerPicker();
    this.registerFiltering();
    $("#workflow-template-sidebar").scroll(function() {
      var scroll = $("#workflow-template-sidebar").scrollTop();
      if (scroll > 0) {
        $("#workflow-template-sidebar").addClass("bt");
      }
      else {
        $("#workflow-template-sidebar").removeClass("bt");
      }
    });

    $(window).on("load", () => {
      $("[workflow-preview]").each((index, img) => {
        $(img).width(function(_, v) { return v / 2 });
      });
    })
  },

  showTemplate: function(templateTitle) {
    $("div[workflow-template]").removeClass("bg-white");
    $("div[workflow-template]").removeAttr("selected");

    let templateToShow = $(`div[workflow-template][id='${templateTitle}']`);
    templateToShow.addClass("bg-white").removeClass("hover-bg-white").attr("selected", true);

    let template = this.templates.find(template => template.title === templateTitle);
    $("#chosen-template-features").empty();
    template.features.forEach((feature) => {
      $("#chosen-template-features").append(`<li>${feature}</li>`);
    });

    $("#chosen-template-icon").attr("src", `${window.InjectedDataByBackend.AssetsPath}/images/${template.icon}`);

    $("img[workflow-preview]").hide();
    if(template.preview != null) {
      $(`img[workflow-preview][templateTitle='${templateTitle}']`).show();
    }

    $("#chosen-template-title").empty();
    $("#chosen-template-title").append(template.title);

    $("#chosen-template-description").empty();
    $("#chosen-template-description").append(template.description);

    $("#chosen-template-yaml").empty();
    $("#chosen-template-yaml").append(template.template_content);
    document.querySelectorAll("#chosen-template-yaml").forEach((block) => {
      hljs.highlightBlock(block);
    });
  },

  registerFiltering: function() {
    $("body").on("keyup", "#template-filter", function(event) {
      let term = event.currentTarget.value.trim();

      if(term == "") {
        $("[workflow-template-limiter]").show();
      } else {
        $("[workflow-template-limiter]").hide();
      }

      TemplatePicker.filterByTerm(term);
    });
  },

  filterByTerm: function(term) {
    term = term.toLowerCase();
    $("#template-not-found").hide();
    $("[workflow-template]").hide();
    $("[workflow-template]").filter(function(index, element) {
      let title = $(element).data("title").toLowerCase();
      let description = $(element).data("description").toLowerCase();

      if(title.includes(term) || description.includes(term)) {
        return true;
      } else {
        return false
      }
    }).show();

    if($("[workflow-template]:visible").length == 0) {
      $("#template-not-found").show();
      $("[workflow-template][fallback]").show();
    }
  },

  registerPicker: function() {
    let projectName = window.InjectedDataByBackend.ProjectName;

    $("body").on("click", "div[workflow-template]", function(event) {
      let target = $(event.currentTarget);
      let templateTitle = target.attr("id");
      TemplatePicker.showTemplate(templateTitle);
    });

    $("body").on("click", "a[run-workflow]", function(event) {
      // Disable form
      $(event.currentTarget).addClass("btn-working");
      $(event.currentTarget).disabled = true;
      $(event.currentTarget).empty();
      $(event.currentTarget).append("Starting your workflow...");

      // Commit starter workflow
      let body = new FormData();

      let csrf = $("meta[name='csrf-token']").attr("content");
      let templatePath = $("div[workflow-template][selected]").data("path");
      let templateTitle = $("div[workflow-template][selected]").data("title");
      let workflowTip = $("div[workflow-template][selected]").data("workflow-tip");

      body.append("_csrf_token", csrf)
      body.append("templatePath", templatePath);
      body.append("templateTitle", templateTitle);

      fetch("commit_starter_template", {
        method: "POST",
        body: body
      }).then((response) => {
        return response.json();
      }).then((data) => {
        if(data.error) {
          Notice.error(data.error);
        } else {
          TemplatePicker.afterCommitHandler(data.branch, data.commit_sha, workflowTip, projectName);
        }
      });

      event.preventDefault();
    });

    $("body").on("click", "a[customize-template]", function(event) {
      let templatePath = $("div[workflow-template][selected]").data("path");
      let templateTitle = $("div[workflow-template][selected]").data("title");
      let workflowTip = $("div[workflow-template][selected]").data("workflow-tip");
      let workflowBuilderPath = $(event.currentTarget).attr("href");

      if(workflowTip && workflowTip != "") {
        document.cookie = `${projectName}-workflow-tip=${workflowTip}; path=/;`;
      }
      window.location = `${workflowBuilderPath}?templatePath=${templatePath}&templateTitle=${templateTitle}`;
      event.preventDefault();
    });
  },

  afterCommitHandler: function(branch, commitSha, workflowTip, projectName) {
    var query = [`branch=${encodeURIComponent(branch)}`, `commit_sha=${encodeURIComponent(commitSha)}`].join("&")
    var url   = "check_workflow?" + query

    console.log(`Checking workflows ${url}`)

    fetch(url)
    .then((res) => {
      var contentType = res.headers.get("content-type");

      if(contentType && contentType.includes("application/json")) {
        return res.json();
      } else {
        throw new Error(res.statusText);
      }
    })
    .then((data) => {
      if(data.workflow_url == null) {
        setTimeout(TemplatePicker.afterCommitHandler.bind(TemplatePicker, branch, commitSha, workflowTip, projectName), 1000)
      } else {
        if(workflowTip && workflowTip != "") {
          document.cookie = `${projectName}-workflow-tip=${workflowTip}; path=/;`;
        }
        window.location = `${data.workflow_url}`;
      }
    })
    .catch(
      (reason) => { console.log(reason); }
    )
  }
}
