# logseq_block_spacer

A plugin for Logseq to keep first child block empty.
<!-- A plugin for Logseq to keep first child block and last child block empty and insert block between two blocks by click mouse. -->

## Features

- [x] Keep first child block empty.
  - If there is no child block, the plugin will do nothing.
  - If the first child block is not empty and include some built-in property like *alias*, *public*, *template* and so on, the plugin will keep the first child block and insert a new block after it.
<!-- - [ ] Keep last child block empty.
- [ ] Insert block between two blocks. -->

## Development

Fork [this repo](https://github.com/gfgafn/logseq_block_spacer.git) and clone it to your local machine. Then run the following commands:

```shell
npm install pnpm --global

pnpm install

pnpm run dev
```

Open Logseq desktop app, open the Settings and enable "Developer Mode" then load plugin using "Load unpacked plugin" by selecting the root folder of this project.
Make some changes to the code, then submit a pull request.

## Build

```shell
pnpm run build
```

## License

MIT License
