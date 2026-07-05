FROM elixir:1.17-otp-27-slim AS build

RUN apt-get update -y && apt-get install -y ca-certificates gcc make libc6-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

RUN for i in 1 2 3 4 5; do mix local.hex --force && mix local.rebar --force && break || sleep 5; done

COPY mix.exs mix.lock* ./
RUN for i in 1 2 3 4 5; do mix deps.get --only prod && break || sleep 5; done

COPY config config
COPY lib lib
COPY priv priv
COPY assets assets
COPY .formatter.exs ./

RUN mix deps.compile && mix compile
RUN for i in 1 2 3 4 5; do mix esbuild.install --if-missing && break || sleep 5; done
RUN mix assets.deploy
RUN mix release

FROM debian:bookworm-slim

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/_build/prod/rel/budget_sentinel ./
COPY entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENV PHX_SERVER=true
EXPOSE 4000

CMD ["./entrypoint.sh"]
