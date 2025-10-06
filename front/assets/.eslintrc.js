// ESLint configuration file
// https://eslint.org/docs/latest/user-guide/configuring/

module.exports = {
  env: {
    browser: true,
    es2020: true,
  },
  extends: "eslint:recommended",
  globals: {
    Atomics: "readonly",
    SharedArrayBuffer: "readonly",
    dagreD3: "readonly",
    d3: "readonly",
    escapeHtml: "readonly",
    InjectedDataByBackend: "readonly",
    CodeMirror: "readonly",
    Notice: "readonly",
    tippy: "readonly",
    mixpanel: "readonly",
  },
  parserOptions: {
    ecmaVersion: 2020,
    tsconfigRootDir: __dirname,
    sourceType: "module",
  },
  ignorePatterns: ["*.js", "*.json"],
  rules: {},
  overrides: [
    {
      files: ["js/**/*.spec.js"],
      env: {
        mocha: true,
      },
    },
    {
      env: {
        browser: true,
        es2018: true,
        mocha: true,
      },
      files: ["js/**/*.{ts,tsx}"],
      parser: "@typescript-eslint/parser",
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
        project: "./tsconfig.json",
      },
      plugins: ["@typescript-eslint"],
      extends: [
        "eslint:recommended",
        "plugin:@typescript-eslint/recommended",
        "plugin:@typescript-eslint/eslint-recommended",
        "plugin:@typescript-eslint/recommended-requiring-type-checking",
        "plugin:react/recommended",
      ],
      rules: {
        "@typescript-eslint/no-namespace": "off",
        "@typescript-eslint/no-explicit-any": "off",
        "no-multiple-empty-lines": "error",
        "no-unexpected-multiline": "error",
        indent: "off",
        quotes: ["error", "backtick"],
        "@typescript-eslint/indent": ["error", 2],
        "@typescript-eslint/semi": ["error"],
        "@typescript-eslint/consistent-type-definitions": [
          "error",
          "interface",
        ],
        "@typescript-eslint/no-unsafe-assignment": "off",
        "@typescript-eslint/unbound-method": "off",
        "@typescript-eslint/no-unsafe-member-access": "off",
        "@typescript-eslint/no-unsafe-call": "off",
        "@typescript-eslint/object-curly-spacing": ["error", "always"],
        "@typescript-eslint/type-annotation-spacing": [
          "error",
          {
            before: false,
            after: true,
            overrides: {
              arrow: {
                before: true,
                after: true,
              },
            },
          },
        ],
        "no-console": ["error", { allow: ["warn", "error"] }],
        "max-len": ["error", {"code": 120, "ignoreComments": true}],
        "no-multi-spaces": "error",
        "@typescript-eslint/member-delimiter-style": [
          "warn",
          {
            multiline: {
              delimiter: "semi",
              requireLast: true,
            },
            singleline: {
              delimiter: "comma",
              requireLast: false,
            },
          },
        ],
        "semi-spacing": ["error", {"before": false, "after": true}],
        "react/jsx-uses-react": "off",
        "react/react-in-jsx-scope": "off",
        "react/display-name": "off",
        "react/jsx-tag-spacing": [
          "error",
          {
            closingSlash: "never",
            beforeSelfClosing: "never",
            afterOpening: "never",
            beforeClosing: "never",
          },
        ],
        "@typescript-eslint/no-misused-promises": [
          "error",
          {
            "checksVoidReturn": false
          }
        ]
      },
    },
  ],
};
