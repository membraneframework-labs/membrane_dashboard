# Membrane Dashboard 

This repository contains a dashboard for monitoring Membrane's pipelines.

Currently the dashboard relies on information persisted by `membrane_timescaledb_reporter` to 
the TimescaleDB database from which the dashboard queries information. 

Major functionalities:
* Search performed on specific time range constant refresh with a  `live mode` being updated every 5 seconds
* Pipelines' elements diagram with a set of interactive controls allowing for the following: 
    - exporting diagram to a file 
    - focusing a certain pipeline on a diagram
    - selecting a subset of elements that the chart should limit display to 
    - in case of invalid pipeline termination manually marking the pipeline as dead
* Charts plotting selected metrics values for each present element that has emitted them previously 
    
Optional functionalities:
* Zipkin's opentelemetry traces search (to use you must set `USE_ZIPKIN=true` environmental variable and optionally `ZIPKIN_URL` which defaults to `http://localhost:9411` which is a default
  zipkin's address when running locally)

**IMPORTANT**

Make sure that you have enabled `membrane_core`'s telemetry in your application. By default any core's metrics are turned off
therefore dashboard will not be able to display information. 

For available metrics please refer to the latest core's master branch
[Membrane.Telemetry](https://github.com/membraneframework/membrane_core/blob/3193167ee8eb2d842006d43937d06bda9933d37f/lib/membrane/telemetry.ex#L30) module.

To display pipeline diagrams make sure that `:links` and `:inits_and_terminates` telemetry flags are present,
for certain metrics to be present on charts make sure that the desired metrics are added under `:metrics` key. 

## Usage

Membrane dashboard is a simple Phoenix application utilizing live view components.

First install dependencies:
```bash
mix deps.get
npm ci --prefix ./assets
```

To run the application you need to provide a few necessary environment variables:
* for timescaleDB configuration (used by Ecto.Repo):
    * DB_USER - username
    * DB_PASS - password
    * DB_NAME - database
    * DB_HOST - hostname
* server host:
    * HOST - hostname to access the application

You can also pass one optional environment variable:
* PORT - port at which the application will be available

Running example:
```bash
DB_USER=postgres DB_PASS=postgres DB_NAME=membrane_timescaledb_reporter DB_HOST=localhost HOST=localhost mix phx.server
```

Application uses port `8000` by default. If `HOST=localhost`, dashboard will be available at address `http://localhost:8000`.

## Dashboard functionalities


## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_dashboard)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_dashboard)

Licensed under the [Apache License, Version 2.0](LICENSE)
