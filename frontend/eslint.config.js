import js from "@eslint/js";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default [
  { ignores: ["dist/**", "node_modules/**"] },
  js.configs.recommended,
  {
    files: ["**/*.{js,jsx}"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      parserOptions: {
        ecmaFeatures: { jsx: true },
      },
      globals: {
        window: "readonly",
        document: "readonly",
        console: "readonly",
        localStorage: "readonly",
        setTimeout: "readonly",
        clearTimeout: "readonly",
        navigator: "readonly",
        fetch: "readonly",
        URL: "readonly",
        URLSearchParams: "readonly",
        crypto: "readonly",
        indexedDB: "readonly",
        TextDecoder: "readonly",
        TextEncoder: "readonly",
      },
    },
    plugins: {
      react,
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      "react/prop-types": "off",
      "react/jsx-uses-vars": "error",
      "react-refresh/only-export-components": "warn",
      "no-unused-vars": "error",
      "no-undef": "error",
      "react-hooks/exhaustive-deps": "error",
      "react-hooks/set-state-in-effect": "off"
    },
    settings: {
      react: { version: "18.3" },
    },
  },
  {
    files: ["**/*.test.{js,jsx}", "src/setupTests.js"],
    languageOptions: {
      globals: {
        global: "readonly",
      },
    },
  },
  {
    // vite.config.js executa em Node (fase de build), não no browser — só
    // esse arquivo precisa do global process (DEC-28, base path condicional).
    files: ["vite.config.js"],
    languageOptions: {
      globals: {
        process: "readonly",
      },
    },
  },
];
