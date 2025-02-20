export var Fork = {
  init: function(defaultProvider) {
    this.setProvider(defaultProvider);
    this.handleProviderChanges();
  },

  setProvider: function(provider) {
    let tabs = document.querySelectorAll(`[data-tab]`)
    tabs.forEach(function(tab) {
      tab.classList.remove("bg-purple", "white")
      tab.classList.add("bg-white", "purple")
    });
    let tab = document.querySelector(`[data-tab='${provider}']`)
    tab.classList.add("bg-purple", "white")
    tab.classList.remove("bg-white", "purple")

    let allRepositories = document.querySelectorAll(`[data-provider]`)
    let providerRepositories = document.querySelectorAll(`[data-provider='${provider}']`)

    allRepositories.forEach(function(repo) { repo.classList.add("dn") })
    providerRepositories.forEach(function(repo) { repo.classList.remove("dn") })
  },

  handleProviderChanges: function() {
    let tabs = document.querySelectorAll(`[data-tab]`)

    tabs.forEach(function(tab) {
      tab.addEventListener("click", () => {
        Fork.setProvider(tab.dataset.tab)
      })
    })
  }
};
