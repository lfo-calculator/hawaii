#!/usr/bin/env sh

# abort on errors
set -e

# build
yarn run build

# for some reason the paths start with /hawaii-lfo FIXME
mv dist hawaii-lfo

# if you are deploying to a custom domain
# echo 'hawaii.lfocalculator.org' > CNAME

git init
git add -A hawaii-lfo
git commit -m 'deploy'

# if you are deploying to https://<USERNAME>.github.io
# git push -f git@github.com:<USERNAME>/<USERNAME>.github.io.git main

# if you are deploying to https://<USERNAME>.github.io/<REPO>
git push -f git@github.com:lfocalculator/hawaii.git main:gh-pages
