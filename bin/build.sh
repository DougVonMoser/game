#!/usr/bin/env bash

set -e

export LANG=en_US.UTF-8
export LANGUAGE=en_US
export LC_ALL=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

export MIX_ENV=prod 
export SECRET_KEY_BASE=superdupersecret 


function do_install(){

    echo "==> doing this step of an install "
}

function do_pre_build(){
    echo "==> Installing project dependencies"
    mix deps.get --only prod 
    npm install --prefix ./assets
}

function do_build(){
    echo "==> Building release.."
    npm run prod --prefix ./assets
    mix phx.digest
}

function do_post_build(){
    echo "==> creating and tarring release.."
    mix release first_deploy --overwrite
    tar -cvf testing.tar ./_build/prod/rel/first_deploy
}



if [ -z "$1" ]; then
    echo "You must pass a task to execute! Expected one of (install|build|pre_build|post_build)"
    exit 1
fi

case $1 in
    build)
        do_build
        ;;
    pre_build)
        do_pre_build
        ;;
    post_build)
        do_post_build
        ;;
    install)
        do_install
        ;;
    all)
        do_install && \
          do_pre_build && \
          do_build && \
          do_post_build
        ;;
    *)
        echo "Invalid command $1"
        exit 1
        ;;
esac

exit 0
~
