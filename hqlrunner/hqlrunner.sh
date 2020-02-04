#!/usr/bin/env bash

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
set -o errtrace
# Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
set -o nounset
# Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail

usage()
{
  echo "Usage: $0 [-p] [-s] [-t] [ -a APP_NAME ] SCHEMA1 SCHEMA2 SCHEMA3..."
    echo ""
    echo "    -p: Optional parameter that runs all the hql in parallel."
    echo ""
    echo "    -s: Optional parameter that runs the hql of ./in/APP_NAME/src/ dir only."
    echo "        Default will run hql from ./in/APP_NAME/ dir (unless -s or -t switch is used)."
    echo "        Dir: ./in/APP_NAME/src must exist."
    echo ""
    echo "    -t: Optional parameter that runs the hql of ./in/APP_NAME/tgt/ dir only."
    echo "        Default will run hql from ./in/APP_NAME/ dir (unless -s or -t switch is used)."
    echo "        Dir: ./in/APP_NAME/tgt must exist."
    echo ""
    echo "    -a: Parameter which specifies the APP_NAME."
    echo "        Dir: ./in/APP_NAME must exist."
}

# Print a helpful message if a pipeline with non-zero exit code causes the
# script to exit as described above.
# trap 'echo "Aborting due to errexit on line $LINENO. Exit code: $?" >&2' ERR

# set_variable()
# {
#   local varname=$1
#   shift
#   if [ -z "${!varname}" ]; then
#     eval "$varname=\"$@\""
#   else
#     echo "Error: $varname already set"
#     usage
#   fi
# }

is_all_hql_run_parallel="false"
hql_root_dir=

while getopts 'psta:' OPTION; do
  case "$OPTION" in
    l)
      echo "parallel"
      ;;

    h)
      echo "h stands for h"
      ;;

    a)
      avalue="$OPTARG"
      echo "The value provided is $OPTARG"
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"