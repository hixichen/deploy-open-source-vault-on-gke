#!/usr/bin/env bash
set -ex

git checkout --orphan latest_branch
git add -A
git commit -am "clean up commit history"
git branch -D main
git branch -m main
git push -f origin main