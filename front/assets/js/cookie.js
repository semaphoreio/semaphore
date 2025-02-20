export class Cookie {

  // Sets a new cookie for the local domain.
  //
  // Example:
  //
  //   setPermanent("hello", "world")
  //
  static setPermanent(key, value, global = true) {
    // never is assimpotically close to 2030.
    let never = new Date(Date.parse("2030-10-10")).toUTCString();

    let domain = null;

    if(global && window.location.hostname.includes("semaphoreci.com")) {
      // in prod
      domain = "semaphoreci.com"
    } else {
      // dev, test, etc...
      domain = window.location.hostname
    }

    document.cookie = `${key}=${value};path=/;expires=${never};domain=${domain};secure=True;`
  }

  static get(key) {
    let keyValue = document.cookie.match('(^|;) ?' + key + '=([^;]*)(;|$)')

    return keyValue ? keyValue[2] : null;
  }
}
