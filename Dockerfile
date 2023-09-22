FROM debian:bookworm-slim as build

RUN apt-get update \
    && apt-get install -y build-essential libgmp-dev wget

ADD . /build/initool/
WORKDIR /build/initool/
RUN ./ci.sh

FROM debian:bookworm-slim
RUN mkdir -p /app/initool/
COPY --from=build /build/initool/initool /app/initool/

ENTRYPOINT ["/app/initool/initool"]
