#!/bin/bash

gitTag="${1}"

git checkout -B "release/${gitTag}"

sed -i s/"version: $(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | tr -d "'")"/"version: ${gitTag}"/g pubspec.yaml
git add pubspec.yaml
git commit -m "$(git log -1 --pretty=%B) - Release ${gitTag}"

git push origin "release/${gitTag}" && git checkout - && git merge "release/${gitTag}" && git branch -D "release/${gitTag}"

exit "${?}"