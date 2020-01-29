#!/bin/bash

set -e

export MIX_ENV="prod"
export SECRET_KEY_BASE="superdupersecret"
export LANG="C.UTF-8"

echo "rim raffing old deps, _build, and node_modules"
rm -rf deps
rm -rf _build
rm -rf assets/node_modules/

echo "mix deps.get --only prod "
mix deps.get --only prod 

echo "npm install --prefix assets"
npm install --prefix assets

echo "npm run prod --prefix assets"
npm run prod --prefix assets
    
echo "mix phx.digest"
mix phx.digest

echo "mix release first_deploy --overwrite"
mix release first_deploy --overwrite

echo "cp _build/prod/first_deploy-0.1.0.tar.gz first_deploy-0.1.0.tar.gz"
cp _build/prod/first_deploy-0.1.0.tar.gz first_deploy-0.1.0.tar.gz

