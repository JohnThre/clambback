FROM alpine:3.20

COPY . /src/clambback
RUN apk add --no-cache --virtual .build-deps \
        build-base \
        cmake \
        boost-dev \
        openssl-dev \
    && cmake -S /src/clambback -B /tmp/clambback-build -DENABLE_MYSQL=OFF -DSYSTEMD_SERVICE=OFF \
    && cmake --build /tmp/clambback-build --parallel \
    && strip -s /tmp/clambback-build/clambback \
    && mv /tmp/clambback-build/clambback /usr/local/bin/clambback \
    && rm -rf /src/clambback /tmp/clambback-build \
    && apk del .build-deps \
    && apk add --no-cache --virtual .clambback-rundeps \
        libstdc++ \
        boost-program_options \
        openssl

WORKDIR /config
CMD ["clambback", "config.json"]
