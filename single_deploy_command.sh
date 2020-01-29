#!/bin/bash

set -e

docker run -v $(PWD):/workdir/yay butts bash do_deploy.sh

#will add ec2 commands to copy relasea and whatnot
