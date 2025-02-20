// nycjs code coverage configuration file
// https://github.com/istanbuljs/nyc#common-configuration-options
module.exports = {
  "extends": "@istanbuljs/nyc-config-typescript",
  "all": true,
  "include": [
    "js/**/*.{ts,tsx}",
    "js/**/*.{js,jsx}"
  ],
  "exclude": [
    "js/**/*.spec.js"
  ],
  "reporter": [
    "text",
    "text-summary"
  ]
}
