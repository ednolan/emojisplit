#!/usr/bin/env bash

set -euo pipefail
shopt -s inherit_errexit nullglob
export BASHOPTS

set -x

declare docker_build_script_dir=$(realpath $(dirname "$BASH_SOURCE"))

function main() {
    local tmpdir=$(mktemp -d)
    cp -r "$docker_build_script_dir/"* "$tmpdir"
    cd "$tmpdir"
    export SWIFT_BUILD_UID=$(id -u)
    export SWIFT_BUILD_GID=$(id -g)
    docker build -t emojisplit -f "$docker_build_script_dir/Dockerfile" --build-arg SWIFT_BUILD_UID=${SWIFT_BUILD_UID} --build-arg SWIFT_BUILD_GID=${SWIFT_BUILD_GID} .
    cd -
    rm -r "$tmpdir"
}

[[ "${BASH_SOURCE[0]}" != "${0}" ]] || main "$@"
