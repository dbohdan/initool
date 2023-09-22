FROM debian:bookworm-slim as build

RUN mkdir -p /build/initool/
WORKDIR /build/initool/

ADD . /build/initool/
RUN apt-get update \
    && apt-get install -y build-essential libgmp-dev wget
RUN ./ci.sh

FROM debian:bookworm-slim
RUN mkdir -p /app/initool/
WORKDIR /app/initool/
COPY --from=build /build/initool/initool /app/initool/

ENTRYPOINT ["/app/initool/initool"]
