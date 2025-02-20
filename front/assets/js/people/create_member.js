import $ from "jquery";

export class CreateMember {
  static handlePasswordReveal() {
    const password = $(".people-password")
    const revealButton = $(".people-password-reveal")

    revealButton.on('click', () => {
      revealButton.hide();
      password.show();
    })
  }
}

