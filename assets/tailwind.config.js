module.exports = {
  mode: "jit",
  purge: {
    content: [
      "./src/**/*.ts",
      "../lib/*_web/**/*.*ex",
      "../lib/*_web/**/*.*heex",
      "../lib/*_web/**/*.*html",
    ],
    safelist: ["u-title", "u-label", "u-value"],
  },
  theme: {
    extend: {
      colors: {
        primary: "#0b0d10",
        secondary: "#131619",
      },
    },
  },
  variants: {
    extend: {},
  },
};
