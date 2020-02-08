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


EC2_CURR_DPLY_PUBLIC_DNS=`aws --profile=personal --region=us-east-2 ec2 describe-instances | jq -r '.Reservations[].Instances[].PublicDnsName'`

# copy the embedded script and the release 
scp -i ~/Downloads/code_names_kick.pem embedded_script.sh ec2-user@$EC2_CURR_DPLY_PUBLIC_DNS:~
scp -i ~/Downloads/code_names_kick.pem first_deploy-0.1.0.tar.gz ec2-user@$EC2_CURR_DPLY_PUBLIC_DNS:~

# kick off that embedded script
ssh -i ~/Downloads/code_names_kick.pem ec2-user@$EC2_CURR_DPLY_PUBLIC_DNS bash embedded_script.sh


