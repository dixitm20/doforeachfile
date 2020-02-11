#!/usr/bin/env bash

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

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
# shellcheck disable=SC2034,SC2015
__invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"

echo "__dir: ${__dir}"
echo "__file: ${__file}"
echo "__base: ${__base}"
echo "__invocation: ${__invocation}"

pyspark_filename="${1}"
pyspark_file="${__dir%%/}/${1}"

# check if pyspark file exists
[[ ! -f "${pyspark_file}" ]] && { echo "Missing Pyspark File: '${pyspark_file}'. Aborting"; exit 1; }

dqspool_dir="${__dir%%/}/dqspool"
dqspool_run_file="${dqspool_dir%%/}/$(basename "${pyspark_file}" .py).run"
dqspool_success_file="${dqspool_dir%%/}/$(basename "${pyspark_file}" .py).success"

echo "dqspool_run_file: ${dqspool_run_file}"
echo "dqspool_success_file: ${dqspool_success_file}"

# Create spool dir if not exists
[[ -d "${dqspool_dir}" ]] || mkdir -p "${dqspool_dir}"

# Delete all 

if [[ -f "${dqspool_success_file}" ]]
then
    
fi

