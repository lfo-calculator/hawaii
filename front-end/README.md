# Vuetify front-end for Hawaii LFO

## Overview

This section of the repo contains an example front-end for the Catala LFO Compiler. It consists of two components:

* Vuetify form-based app
* Simple JSON server hosting the ```hawaii-regulations.json``` file.

## Project setup

### Vue project setup

Clone the project

```
gh repo clone lfo-calculator/hawaii
```

Navigate the directory you just cloned and run the following command. If you don't have yarn installed, you can [read about how to here](https://classic.yarnpkg.com/). 

``` cli
yarn install
```

#### Compiles and hot-reloads for development

``` cli
yarn serve
```

#### Compiles and minifies for production

``` cli
yarn build
```

#### Lints and fixes files

```
yarn lint
```

#### Customize configuration

See [Configuration Reference](https://cli.vuejs.org/config/).

### JSON server setup

For the Vue front-end to properly consume the list of Hawaii regulations, it needs to he hosted at a URI accessible to the app.

#### Install JSON Server

Install [JSON Server](https://www.npmjs.com/package/json-server)

```
npm install -g json-server
```

Navigate (or point) to the data directory containing the regulation json file and run this command to start

``` text
json-server --watch hawaii-regulations.json
```

You should see the following output

``` text
\{^_^}/ hi!

  Loading hawaii-regulations.json
  Done

  Resources
  http://localhost:3000/regulations

  Home
  http://localhost:3000
```

If you navigate to ```http://localhost:3000/regulations``` with your browser you should see the following:

```
[
  {
    "regulation": "Short title",
    "reg_url": "https://sammade.github.io/aloha-io/title-17/chapter-286/section-286-1/",
    "section": "286-1",
    "range": "0",
    "violation": "false"
  },
  {
    "regulation": "Definitions",
    "reg_url": "https://sammade.github.io/aloha-io/title-17/chapter-286/section-286-2/",
    "section": "286-2",
    "range": "0",
    "violation": "false"
  },
  [snip]
]
```

If you encounter port conflicts you can specify a known-open port via the following:

  ```
  $ json-server --watch db.json --port 3004
  ```