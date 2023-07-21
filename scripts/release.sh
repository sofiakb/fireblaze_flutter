#!/bin/bash

gitTag="${1}"

git checkout -B "release/${gitTag}" && git push origin "release/${gitTag}" && git checkout - && git branch -D "release/${gitTag}"

exit "${?}"