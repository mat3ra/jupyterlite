# Mat3ra-Jupyterlite

Available at [https://mat3ra-jupyterlite.netlify.app/lab/index.html](https://mat3ra-jupyterlite.netlify.app/lab/index.html).

# JupyterLite Environment

[![lite-badge](https://jupyterlite.rtfd.io/en/latest/_static/badge.svg)](https://jupyterlite.github.io/demo)

JupyterLite deployed as a static site to GitHub Pages, for demo purposes.

## ✨ Try it in your browser ✨

➡️ **https://jupyterlite.mat3ra.com**

![github-pages](https://user-images.githubusercontent.com/591645/120649478-18258400-c47d-11eb-80e5-185e52ff2702.gif)

## Development Notes

### Extensions

The environment using the [data-bridge extension](https://github.com/Exabyte-io/mat3ra-jupyterlite-extension-data-bridge) (see [requirements.txt](dependencies/requirements.txt)).

### Content

The content is based on the [api-examples](https://github.com/Exabyte-io/api-examples.git). And is being populated during build.

### Build

As below:

To build and run the environment locally:

1. check that `npm` is installed
2. run:
```bash
npm install
npm run build
npm start
```

See [github workflow](.github/workflows/deploy.yml) and [package.json](package.json) for more information.

TEST PR
