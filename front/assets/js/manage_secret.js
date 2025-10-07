import $ from "jquery"

import TomSelect from 'tom-select'


export var ManageSecret = {
  init: function () {
    this.envVars = InjectedDataByBackend.Secrets.EnvVars || [];
    this.files = InjectedDataByBackend.Secrets.Files || [];
    this.addEmptyEnvVar();
    this.addEmptyFile();

    this.showEnvVars();
    this.showFiles();

    this.cloneEnvVarInputOnClick();
    this.cloneFileInputOnClick();

    this.showProjectList();
  },

  addEmptyEnvVar: function() {
    this.envVars.push({value: "", name: ""})
  },

  addEmptyFile: function() {
    this.files.push({path: "", content: ""})
  },

  envVarElement: function(envVar, index) {
    let envVarNameId = `env_vars_${index}_name`;
    let envVarNameName = `env_vars[${index}][name]`;
    let envVarOldNameId = `env_vars_${index}_old_name`;
    let envVarOldNameName = `env_vars[${index}][old_name]`;
    let envVarValueId = `env_vars_${index}_value`;
    let envVarValueName = `env_vars[${index}][value]`;
    const envVarDivId = `secrets_${index}_env_var`;
    const envVarDeleteLink = `secrets_${index}_var_delete_link`;
    const envVarMd5Id = `env_vars_${index}_md5`
    const envVarMd5Name = `env_vars[${index}][md5]`

    let element =
      `<div class="flex-ns items-start mv2 bg-washed-gray ba b--lighter-gray pa2 br3 bg-white">
        <div class="w-100 w-50-ns mr2 mb2 mb0-ns">
          <input id=${envVarOldNameId} name=${envVarOldNameName} value='${envVar.name}' type="hidden">
          <input id=${envVarNameId} class="form-control w-100 f5 code" value='${envVar.name}' name=${envVarNameName} type="text" placeholder="Variable Name">
          <input id=${envVarMd5Id} style="display: none" value='${envVar.md5}' name=${envVarMd5Name} type="text">
        </div>

        <div class="w-100 w-50-ns">
          <input id=${envVarValueId} class="form-control w-100 f5 code" style="${envVar.name? "display: none" : ""}" value='${envVar.value}' name=${envVarValueName} type="text" placeholder="Value">

          <div id=${envVarDivId} class="secret-manipulation flex items-center ba b--light-gray ph2 h2 br2 bg-washed-gray" style="${envVar.name ? "" : "display: none"}">
            <div class="flex-auto f5 code overflow-x-scroll">
                MD5:&nbsp;${envVar.md5}
            </div>

            <div class="flex-shrink-0 pl2">
              <a href="#" id=${envVarDeleteLink} class="secret-manipulation link f3 gray hover-dark-gray">×</a>
            </div>
          </div>
        </div>
      </div>`

    return [element, envVarNameId, envVarDivId, envVarDeleteLink, envVarValueId, envVarMd5Id];
  },

  fileElement: function(file, index) {
    let filePathId = `files_${index}_path`;
    let filePathName = `files[${index}][path]`;
    let oldFilePathId = `files_${index}_old_path`;
    let oldFilePathName = `files[${index}][old_path]`;
    let secretInputId = `secrets_${index}_input`;
    let secretUploadId = `secrets_${index}_upload`;
    let secretUploadName = `secrets[${index}][upload]`;
    let secretUploadLinkId = `secrets_${index}_upload_link`;
    let fileDivId = `secrets_${index}_file`;
    let fileContentId = `files_${index}_content`;
    let fileContentName = `files[${index}][content]`;
    let fileDeleteLink = `secrets_${index}_delete_link`;
    const fileMd5Id = `files_${index}_md5`
    const fileMd5Name = `files[${index}][md5]`
    const fileMd5PresentId = `files_${index}_md5_present`
    const fileImageId = `files_${index}_icon`

    let element =
      `<div class="flex-ns items-start mv2 bg-washed-gray ba b--lighter-gray pa2 br3 bg-white">
        <div class="w-100 w-50-ns mr2 mb2 mb0-ns">
          <input id=${oldFilePathId} name=${oldFilePathName} value='${escapeHtml(file.path)}' type="hidden">
          <input id=${filePathId} class="form-control w-100 code" value='${escapeHtml(file.path)}' name=${filePathName} type="text" placeholder="/path/to/file">
          <input id=${fileMd5Id} style="display: none" value='${file.md5}' name=${fileMd5Name} type="text">
        </div>

        <div class="w-100 w-50-ns">
          <div id=${secretInputId} class="secret-manipulation f5 gray mt1 tr" style="${file.path ? "display: none" : ""}">
            <input id=${secretUploadId} name=${secretUploadName} type="file" style="display: none">
            <a href="#" id=${secretUploadLinkId} class="secret-manipulation gray" >Upload File</a>
          </div>

          <div id=${fileDivId} class="secret-manipulation flex items-center ba b--light-gray ph2 h2 br2 bg-washed-gray" style="${file.path ? "" : "display: none"}">
            <div class="flex-auto f5 code overflow-x-scroll">
              <span id=${fileMd5PresentId} style="${file.md5 ? "" : "display: none"}">MD5:&nbsp;${file.md5}</span>
              <img id=${fileImageId} src="${window.InjectedDataByBackend.Secrets.AssetsPath + "/images/icn-file.svg"}" alt="File icon" class="db mr2" style="${file.md5 ? "display: none" : ""}">
              <input id=${fileContentId} value="${file.content}" name=${fileContentName} type="text" style="display: none">
            </div>

            <div class="flex-shrink-0 pl2">
              <a href="#" id=${fileDeleteLink} class="secret-manipulation link f3 gray hover-dark-gray">×</a>
            </div>
          </div>
        </div>
      </div>`

    return [element, secretUploadLinkId, secretUploadId, fileContentId, fileDivId, secretInputId, fileDeleteLink, fileMd5Id, fileMd5PresentId, fileImageId];
  },

  showEnvVars: function() {
    let secretEditor = this;
    document.getElementById("env-vars-input").innerHTML = "";

    this.envVars.forEach(function(envVar, index) {
      let [element, envVarName, envVarDiv, envVarDeleteLink, envVarInput, md5Id] =
        secretEditor.envVarElement(envVar, index)

      document.getElementById("env-vars-input").insertAdjacentHTML("beforeend", element);

      secretEditor.activateEnvVarDeleteLink(envVarDeleteLink, envVarDiv, envVarInput, md5Id);
      secretEditor.activateEnvVarValidation(envVarName);
    })
  },

  showFiles: function() {
    let secretEditor = this;
    document.getElementById("files-input").innerHTML = "";

    this.files.forEach(function(file, index) {
      let [element, fileUploadLink, fileUpload, fileContent, fileDiv, fileInput, fileDeleteLink, md5Id, fileMd5PresentId, fileImageId] =
        secretEditor.fileElement(file, index);

      document.getElementById("files-input").insertAdjacentHTML("beforeend", element);

      secretEditor.browseFilesOnClick(fileUploadLink, fileUpload);
      secretEditor.formatUploadedFile(fileUpload, fileContent, fileDiv, fileInput, fileDeleteLink, fileMd5PresentId, fileImageId);
      secretEditor.activateFilesDeleteLink(fileDeleteLink, fileDiv, fileInput, fileContent, md5Id);
    });
  },

  cloneEnvVarInputOnClick: function() {
    let secretEditor = this;
    $("body").on("click", "#add-env-vars-input", function() {
      secretEditor.addEmptyEnvVar();

      let envVarIndex = secretEditor.envVars.length - 1;
      let envVar = secretEditor.envVars[envVarIndex];
      let [element, envVarDiv, envVarDeleteLink, envVarInput, md5Id] =
        secretEditor.envVarElement(envVar, envVarIndex);

      document.getElementById("env-vars-input").insertAdjacentHTML("beforeend", element);
      secretEditor.activateEnvVarDeleteLink(envVarDeleteLink, envVarDiv, envVarInput, md5Id);

      return false;
    });
  },

  cloneFileInputOnClick: function() {
    let secretEditor = this;
    $("body").on("click", "#add-files-input", function() {
      secretEditor.addEmptyFile();

      let fileIndex = secretEditor.files.length - 1;
      let file = secretEditor.files[fileIndex];
      let [element, fileUploadLink, fileUpload, fileContent, fileDiv, fileInput, fileDeleteLink, md5Id, fileMd5PresentId, fileImageId] =
        secretEditor.fileElement(file, fileIndex);

      document.getElementById("files-input").insertAdjacentHTML("beforeend", element);

      secretEditor.browseFilesOnClick(fileUploadLink, fileUpload);
      secretEditor.formatUploadedFile(fileUpload, fileContent, fileDiv, fileInput, fileDeleteLink, fileMd5PresentId, fileImageId);
      secretEditor.activateFilesDeleteLink(fileDeleteLink, fileDiv, fileInput, fileContent, md5Id);

      return false;
    });
  },

  activateEnvVarValidation: function (selector) {
    let secretEditor = this;
    $("body").on("change textInput input", "#" + selector, function () {
      valid_name_regex = /^[a-zA-Z_][a-zA-Z0-9_]*$/;
      let name = $(this).val();
      if (name.match(valid_name_regex)) {
        $(this).next(".error-message").remove(); // removes existing error message
      }
      else {
        $(this).next(".error-message").remove(); // removes existing error message
        $(this).after('<p class="f6 fw5 mt1 mb0 red error-message">Invalid variable name!</p>');
      }
    });
  },

  browseFilesOnClick: function(linkId, inputId) {
    $("#files-input").on("click", "#" + linkId, function(event){
      event.preventDefault;
      $("#" + inputId).trigger("click");

      return false;
    });
  },

  formatUploadedFile: function(upload, filesContent, wholeFile, input, fileDeleteLink, fileMd5PresentId, fileImageId) {
    let secretEditor = this;

    $("#files-input").on("change", "#" + upload, function() {
      let file = document.getElementById(upload).files[0]

      let reader = new FileReader();
      reader.onload = function(event){
        let read_file = event.target.result;
        let encoded_file = window.btoa(read_file);

        let secrets_input = $("#" + filesContent);
        secrets_input.val(encoded_file);

        $("#" + fileMd5PresentId).hide();
        $("#" + fileImageId).show();
        $("#" + input).hide();
        $("#" + wholeFile).show();
        $("#" + upload).val(null);
      }

      reader.readAsBinaryString(file);
      return false;
    })
  },

  activateFilesDeleteLink: function(fileDeleteLink, wholeFile, input, filesContent, md5Id) {
    $("#files-input").on("click", "#" + fileDeleteLink, function() {
      $("#" + wholeFile).hide();
      $("#" + input).show();

      let secrets_input = $("#" + filesContent);
      secrets_input.val(null);
      const md5Input = $("#" + md5Id);
      md5Input.val(null);

      return false;
    })
  },

  activateEnvVarDeleteLink: function(envVarDeleteLink, wholeEnvVar, input, md5Id) {
    $("#env-vars-input").on("click", "#" + envVarDeleteLink, function() {
      $("#" + wholeEnvVar).hide();
      $("#" + input).show();
      $("#" + input).val("");

      const md5Input = $("#" + md5Id);
      md5Input.val(null);

      return false;
    })
  },

  showProjectList: function () {
    renderItem = function (data, escape) {
      const labelClass = data.disabled ? "red" : ""

      return `
        <div class="item" data-ts-item="">
          <label class="${labelClass}">${escape(data.text)}</span>
        </div>
      `
    };

    if (document.getElementById("projects")) {
    new TomSelect(`#projects`, {
      sortField: { field: "text" },
      plugins: ['no_backspace_delete', 'remove_button'],
      render: { item: renderItem }
    });
    }

  }

}
