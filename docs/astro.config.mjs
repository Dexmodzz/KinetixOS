import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://dexmodzz.github.io/KinetixOS",
  output: "static",
  build: {
    format: "file"
  },
  markdown: {
    shikiConfig: {
      theme: "github-dark-default",
      wrap: true
    }
  }
});
