#!/usr/bin/env bash

# Reference & lot of the functionality is taken from: https://bash3boilerplate.sh/ && multiple online resources. 
# Thanks to the community!!

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# Turn on traces, useful while debugging but commented out by default
# set -o xtrace

# Echo usage if something isn't right.
usage() { 
    echo "Usage: $0 [-p <80|443>] [-h <string>] [-f]" 1>&2; exit 1; 
}

while getopts ":a:e:p:h" o; do
  case "${o}" in
      p)
          PORT=${OPTARG}
          echo "$PORT IS COOL"
          [[ "$PORT" == "80" || "$PORT" == "443" ]] || usage
          ;;
      h)
          HOST=${OPTARG}
          ;;
      f)  
          FORCE=1
          ;;
      h)  
          usage
          ;;
      :)  
          echo "ERROR: Option -$OPTARG requires an argument"
          usage
          ;;
      \?)
          echo "ERROR: Invalid option -$OPTARG"
          usage
          ;;
  esac
done
shift $((OPTIND-1))

echo "$@"

# Check required switches exist
if [ -z "${PORT}" ] || [ -z "${HOST}" ]; then
    usage
fi

echo "P = ${PORT}"
echo "h = ${HOST}"