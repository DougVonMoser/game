#!/bin/bash

set -e

#butts is the result of below
#docker build -t butts -f Dockerfile.build_env . 
#maybe multi stage builds could help here?

docker run -v $(PWD):/workdir/yay butts bash create_release.sh

#will add ec2 commands to copy relasea and whatnot
