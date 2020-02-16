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

app_name="${1}"
param_env_file="${2}"

if [[ "${app_name}" != "${app_name,,}" ]]
then
    echo "ABORT! : app_name parameter must be in lower case only."
    exit 1
fi

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__filename="$(basename "${__file}")"
__base="$(basename "${__file}" .sh)"
# shellcheck disable=SC2034,SC2015
__invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"

__curr_processid="$$"
__curr_dateid="$(date "+%Y_%m_%d-%H_%M_%S_%N")"
__curr_date_yyyymm="$(date "+%Y%m")"
__curr_date_yyyymmdd="$(date "+%Y%m%d")"
__curr_uid="${__filename}.${__curr_processid}.${__curr_dateid}"


# Set current batch id, generate new id if the batch file is not already present
__batchid_dir="${__dir%%/}/app-batch-info/${app_name}"
[[ -d  "${__batchid_dir}" ]] || mkdir -p "${__batchid_dir}"
__batchid_file="${__batchid_dir%%/}/current-batchid.conf"
__is_set_batch_id="true"
if [[ -s "${__batchid_file}" ]]
then
    RUNTIME_ENV_CURRENT_BATCH_ID="$( cat "${__batchid_file}" | sed -e '/^\s*$/d' -e '/\s*#.*$/d' | tail -1 )"
    if [[ "${RUNTIME_ENV_CURRENT_BATCH_ID:-}" == "" ]]
    then
        export RUNTIME_ENV_CURRENT_BATCH_ID="${__curr_date_yyyymmdd}"
        echo "${RUNTIME_ENV_CURRENT_BATCH_ID}" > "${__batchid_file}"
    else
        __is_set_batch_id="false"
        export RUNTIME_ENV_CURRENT_BATCH_ID="${RUNTIME_ENV_CURRENT_BATCH_ID}"
    fi
else
    export RUNTIME_ENV_CURRENT_BATCH_ID="${__curr_date_yyyymmdd}"
    echo "${RUNTIME_ENV_CURRENT_BATCH_ID}" > "${__batchid_file}"
fi

__log_dir="${__dir%%/}/app-log/${app_name}/${__base}/${RUNTIME_ENV_CURRENT_BATCH_ID}"
[[ -d  "${__log_dir}" ]] || mkdir -p "${__log_dir}"
__log_file="${__log_dir%%/}/${__curr_uid}.log"


__tmp_dir="${__dir%%/}/app-tmp/${app_name}/${__base}/${__curr_uid}.tmp-dir"
[[ -d  "${__tmp_dir}" ]] || mkdir -p "${__tmp_dir}"

common_env_dir="${__dir}/app-conf/common"
app_env_dir="${__dir}/app-conf/${app_name}"
script_env_dir="${__dir}/app-conf/${app_name}/${__base}"
[[ -d  "${common_env_dir}" ]] || mkdir -p "${common_env_dir}"
[[ -d  "${app_env_dir}" ]] || mkdir -p "${app_env_dir}"
[[ -d  "${script_env_dir}" ]] || mkdir -p "${script_env_dir}"

echo "__dir: ${__dir}"
echo "__file: ${__file}"
echo "__filename: ${__filename}"
echo "__base: ${__base}"
echo "__invocation: ${__invocation}"

echo "__curr_processid: ${__curr_processid}"
echo "__curr_dateid: ${__curr_dateid}"
echo "__curr_date_yyyymm: ${__curr_date_yyyymm}"
echo "__curr_date_yyyymmdd: ${__curr_date_yyyymmdd}"
echo "__curr_uid: ${__curr_uid}"
echo "__curr_uid: ${__curr_uid}"

echo "__batchid_dir: ${__batchid_dir}"
echo "__batchid_file: ${__batchid_file}"
echo "__log_dir: ${__log_dir}"
echo "__log_file: ${__log_file}"
echo "__tmp_dir: ${__tmp_dir}"

echo "common_env_dir: ${common_env_dir}"
echo "app_env_dir: ${app_env_dir}"
echo "script_env_dir: ${script_env_dir}"
echo "param_env_file: ${param_env_file}"

if [[ "${__is_set_batch_id}" == "true"  ]]
then 
    echo "Setting RUNTIME_ENV_CURRENT_BATCH_ID: ${RUNTIME_ENV_CURRENT_BATCH_ID}"
fi
echo "export RUNTIME_ENV_CURRENT_BATCH_ID='${RUNTIME_ENV_CURRENT_BATCH_ID}'"




common_env_dir="${__dir}/app-conf/common"
app_env_dir="${__dir}/app-conf/${app_name}"
script_env_dir="${__dir}/app-conf/${app_name}/${__base}"


[[ -d  "${common_env_dir}" ]] || mkdir -p "${common_env_dir}"
[[ -d  "${app_env_dir}" ]] || mkdir -p "${app_env_dir}"
[[ -d  "${script_env_dir}" ]] || mkdir -p "${script_env_dir}"

# source common env 
for file in $(find "${common_env_dir}" -name '*.sh'); 
do
    echo "Sourcing file: '${file}' from common_env_dir: '${common_env_dir}'"
    source "${file}"; 
done

# source app specific env
for file in $(find "${app_env_dir}" -name '*.sh'); 
do
    echo "Sourcing file: '${file}' from app_env_dir: '${app_env_dir}'"
    source "${file}"; 
done

# source script specific env
for file in $(find "${script_env_dir}" -name '*.sh'); 
do
    echo "Sourcing file: '${file}' from script_env_dir: '${script_env_dir}'"
    source "${file}"; 
done

# source param env
source "${param_env_file}"





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

