# adapted from https://github.com/apple/swift-docker/blob/9a4adf44695e8e5a2234ffbdbcb9ff0875a2a089/README.md
FROM swift:latest as builder
RUN mkdir /emojisplit
ARG SWIFT_BUILD_UID
ARG SWIFT_BUILD_GID
RUN useradd -u ${SWIFT_BUILD_UID} -m -d /home/eddie -s /bin/bash eddie
COPY . /emojisplit/
RUN chown -R ${SWIFT_BUILD_UID}:${SWIFT_BUILD_GID} /emojisplit
USER ${SWIFT_BUILD_UID}:${SWIFT_BUILD_GID}
WORKDIR /emojisplit
RUN swift build -c release

FROM swift:slim
WORKDIR /root
COPY --from=builder /emojisplit .
ENTRYPOINT [".build/release/emojisplit"]
