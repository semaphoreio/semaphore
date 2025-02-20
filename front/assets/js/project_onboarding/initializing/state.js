//
// Represents the state of the waiting process.
// It saves the states of the dependacines, and the overall state of the project.
//
// After N seconds of waiting, we are displaying a calming message to the user
// that makes sure that he understands why he is waiting for so much time.
//
// The waiting time is checked by calling `waitedTooLong` method.
//

export class State {
  constructor() {
    this.ready = false

    this.deps = {
      forkingRepository: null,
      connectedToRepository: null,
      connectedToArtifacts: null,
      permissionsSetup: null,
      connectedToCache: null,
      repoAnalyzed: null,
      firstWorkflow: null
    }

    this.errorMessage = ""
    this.waitingMessage = ""
    this.started = new Date().getTime()
  }

  update(data) {
    console.log("Updating project state")

    this.ready = data["ready"]
    this.deps = {
      forkingRepository: data["deps"]["forking_repository"],
      connectedToRepository: data["deps"]["connected_to_repository"],
      connectedToArtifacts: data["deps"]["connected_to_artifacts"],
      connectedToCache: data["deps"]["connected_to_cache"],
      permissionsSetup: data["deps"]["permissions_setup"],
      repoAnalyzed: data["deps"]["repo_analyzed"],
      firstWorkflow: data["deps"]["first_workflow"]
    }
    this.waitingMessage = data["waiting_message"]
    this.errorMessage = data["error_message"]
  }

  waitedTooLong() {
    let now = new Date().getTime()

    return (now - this.started) > 10 * 1000
  }
}
