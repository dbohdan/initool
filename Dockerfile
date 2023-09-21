FROM fedora:40 as build

RUN dnf install mlton diffutils -y
RUN mkdir -p /build/initool
WORKDIR /build/initool

ADD . /build/initool/
RUN make test
RUN make

FROM fedora:40
RUN mkdir -p /app/initool
WORKDIR /app/initool
COPY --from=build /build/initool/initool /app/initool/

ENTRYPOINT [ "/app/initool/initool" ]
