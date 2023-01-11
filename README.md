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
  zipkin's address when running locally, for more information please go see `Membrane.DashboardWeb.Live.Components.Plugins.ZipkinOpentelemetry`).

**IMPORTANT**

Make sure that you have enabled `membrane_core`'s telemetry in your application. By default any core's metrics are turned off
therefore dashboard will not be able to display information. 

For available metrics please refer to the latest core's master branch
[Membrane.Telemetry](https://github.com/membraneframework/membrane_core/blob/3193167ee8eb2d842006d43937d06bda9933d37f/lib/membrane/telemetry.ex#L30) module.

To display pipeline diagrams make sure that `:links` and `:inits_and_terminates` telemetry flags are present,
for certain metrics to be present on charts make sure that the desired metrics are added under `:metrics` key. 

## The simplest way to set all of this up: docker-compose

This requires minimal setup:
1. Clone [this repository](https://github.com/membraneframework/membrane_telemetry_dashboard)
2. Run `docker-compose up` inside the cloned folder
3. Perform [this step](#wiring-a-membrane-pipeline-to-a-membrane_timescaledb_reporter)
4. Access the dashboard at `localhost:8000`

## The simplest way to set all of this up without docker-compose

For this application to work, you need a couple things set up:

  - a TimescaleDB instance running **on port 5432**. If the application the pipeline belongs to also wants a service running on 5432, then you need to change that.
  - a Membrane pipeline with `membrane_timescaledb_reporter` set up to persist reports to the Timescale instance,
  - this app

### Setting up the Timescale instance

This is a set of sample parameters, which should _just work_

```bash
docker run \
-e POSTGRES_DB=membrane_timescaledb_reporter \
-e POSTGRES_USER=postgres \
-e POSTGRES_PASSWORD=postgres \
--name dashboard-timescale \
-d -p 5432:5432 \
timescale/timescaledb:latest-pg14
```

### Wiring a membrane pipeline to a `membrane_timescaledb_reporter`

This is the most complicated part of all of this. First, add `membrane_timescaledb_reporter` to your `mix.exs`:

```elixir
{:membrane_timescaledb_reporter, "~> 0.1.0"}
```
  
Then, run

```
mix deps.get
```

After that, add the following lines to your `config/config.exs`

```elixir
config :membrane_core,
  telemetry_flags: [
    :links,
    :inits_and_terminates,
    {:metrics, [:caps]} # optional line, only add that if you want to
	                      # use some of the metrics
  ]

config :membrane_timescaledb_reporter, Membrane.Telemetry.TimescaleDB.Repo,
  database: "membrane_timescaledb_reporter",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  chunk_time_interval: "3 minutes",
  chunk_compress_policy_interval: "1 minute",
  log: false

config :membrane_timescaledb_reporter,
  reporters: 5,
  auto_migrate?: true
```

You can read about the metrics that can be specified in `telemetry_flags` in the [`Membrane.Telemetry` docs](https://hexdocs.pm/membrane_core/0.11.2/Membrane.Telemetry.html#module-enabling-certain-metrics-events).

The next step is to forcibly recompile `membrane_core`:

```
mix deps.compile --force membrane_core
```

After you do this, the only thing left is to add `Membrane.Telemetry.TimescaleDB` to your supervision tree.  An example from Membrane Live:

```elixir
@impl true
def start(_type, _args) do
  children = [
	Membrane.Telemetry.TimescaleDB, # this is the added line
	MembraneLive.Repo,
	{Phoenix.PubSub, name: MembraneLive.PubSub},
	MembraneLiveWeb.Presence,
	MembraneLiveWeb.Endpoint
  ]

  :ets.new(:presenters, [:public, :set, :named_table])
  :ets.new(:presenting_requests, [:public, :set, :named_table])
  opts = [strategy: :one_for_one, name: MembraneLive.Supervisor]
  Supervisor.start_link(children, opts)
end
```

After this step, your application should automatically log all configured events to the database. If you decided to use `docker-compose`, you don't need to do anything else. If you decided to set up everything by yourself, there's one more step left.

### Running `membrane_dashboard`

Fortunately, this is rather simple. You need to get all the dependencies:

```
mix deps.get
npm ci --prefix=assets
```

Then, run the application, specifying all needed environment variables:

```bash
DB_USER=postgres \ 
DB_PASS=postgres \
DB_NAME=membrane_timescaledb_reporter \
DB_HOST=localhost \
HOST=localhost \
mix phx.server
```

After completing this step, the dashboard should be accessible at `localhost:8000`

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
