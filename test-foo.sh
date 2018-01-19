#!/bin/bash -e

function _return_false(){
  return 1
}

set +e
_return_false
rc=$?
set -e

if [ ${rc} -eq 1 ]; then
  echo "it works"
fi
