# Membrane Dashboard 

This repository contains a dashboard for monitoring Membrane's pipelines.

It uses `membrane_timescaledb_reporter` for obtaining information about pipelines states. 

For now it supports:
* displaying dependency diagram of pipeline's elements for given time range
* charts for monitoring input buffers with live update

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Usage

Membrane dashboard is a simple Phoenix application utilizing live view components.

First install dependencies:
```bash
mix deps.get
npm ci --prefix ./assets
```

And then run. You will need to provide your timescaledb configs as environment variables. For example:
```bash
DB_USER=postgres DB_PASS=postgres DB_NAME=membrane_timescaledb_reporter DB_HOST=localhost SECRET_KEY_BASE=uT0jyRQH9x5jCEYYpACumazKKQz62FWBNFjaX9IXwhzKvHkmP3jLZ75bClryU6Iv HOST=localhost mix phx.server
```

The application will be available at address `http://localhost:4000`.

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_dashboard)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_dashboard)

Licensed under the [Apache License, Version 2.0](LICENSE)
