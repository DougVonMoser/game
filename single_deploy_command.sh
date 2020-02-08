#!/bin/bash

set -e

#butts is the result of below
#docker build -t butts -f Dockerfile.build_env . 
#maybe multi stage builds could help here?


# bind pwd as a volume, but ignore the build folders

docker run -v $(PWD):/workdir/yay                \
           -v /workdir/yay/deps/                 \
           -v /workdir/yay/_build/               \
           -v /workdir/yay/assets/node_modules/  \
           butts bash create_release.sh

#will add ec2 commands to copy relasea and whatnot
