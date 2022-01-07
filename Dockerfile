ARG BUILDER_IMAGE="hexpm/elixir:1.12.3-erlang-24.1.4-debian-bullseye-20210902-slim"
ARG RUNNER_IMAGE="debian:bullseye-20210902-slim"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN \
    apt-get update -y &&  apt-get install -y \
    inotify-tools \
    build-essential \
    npm \
    git \
    curl \
    libssl-dev

# Get Rust (needed for rustler purposes)
RUN curl https://sh.rustup.rs -sSf | bash -s -- -y -v
ENV PATH="/root/.cargo/bin:${PATH}"

# Create build workdir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix do deps.get, deps.compile
# watch out for this, we may want to do that before compiling deps


# build assets
COPY assets/package.json assets/package-lock.json ./assets/
RUN npm --prefix ./assets ci --progress=false --no-audit --loglevel=error

# lib needs to be here so tailwind can scan templates' css classes
COPY lib lib
COPY priv priv
COPY assets assets
RUN mix assets.deploy

# compile and build release
RUN mix do compile, release

# prepare release image
FROM ${RUNNER_IMAGE}

# install runtime dependencies
RUN \
    apt-get update -y && apt-get install -y \
    inotify-tools \
    openssl \
    libncurses5 \
    curl \
    libstdc++6

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/membrane_dashboard ./

ENV HOME=/app

EXPOSE 8000

CMD ["bin/membrane_dashboard", "start"]
