# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
# instead of Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20231009-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.16.0-erlang-26.2.1-debian-bullseye-20231009-slim
#
ARG ELIXIR_VERSION=1.19.2
ARG OTP_VERSION=28.3.2
ARG DEBIAN_VERSION=bookworm-20260202

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

FROM ${BUILDER_IMAGE} AS builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git nodejs npm curl wget openssh-client libopenblas0 \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv

COPY lib lib

COPY assets assets

# compile assets
RUN mix do assets.setup + assets.build + assets.deploy

# Compile the release
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

ARG COMMIT
ENV APP_REVISION=$COMMIT

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates libopenblas0 \
  nodejs npm vim curl wget xz-utils libvips42 libvips-tools librsvg2-2 fontconfig fonts-dejavu-core \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# The Debian `nobody` user has `/nonexistent` as its home directory.
# Fontconfig falls back to `$HOME/.cache/fontconfig`, so provide a writable
# home/cache location for runtime image generation.
ENV HOME="/app"
ENV XDG_CACHE_HOME="/app/.cache"

RUN mkdir -p /app/.cache/fontconfig && chown -R nobody:root /app/.cache

# set runner ENV
ENV MIX_ENV="prod"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/agent_jido ./

# install hivemind (arch-aware: supports both amd64 and arm64)
RUN ARCH=$(dpkg --print-architecture) && \
  wget https://github.com/DarthSim/hivemind/releases/download/v1.1.0/hivemind-v1.1.0-linux-${ARCH}.gz && \
  gunzip hivemind-v1.1.0-linux-${ARCH}.gz && \
  chmod +x hivemind-v1.1.0-linux-${ARCH} && \
  mv hivemind-v1.1.0-linux-${ARCH} ./bin/hivemind

COPY Procfile ./
COPY entrypoint ./bin
RUN chmod +x ./bin/entrypoint

USER nobody

ENTRYPOINT ["/app/bin/entrypoint"]
