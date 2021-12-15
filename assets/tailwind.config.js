module.exports = {
  mode: "jit",
  purge: {
    content: [
      "./src/**/*.ts",
      "../lib/*_web/**/*.*ex",
      "../lib/*_web/**/*.*heex",
      "../lib/*_web/**/*.*html",
    ],
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
