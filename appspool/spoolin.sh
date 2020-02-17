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

PROCESS_NAME="APP_FRAMEWORK"
# >>> Set magic variables for current file, directory, os etc. >>>
##############################################################################
    __dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    __file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
    __filename="$(basename "${__file}")"
    __base="$(basename "${__file}" .sh)"
    __invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"

    __curr_processid="$$"
    __curr_dateid="$(date "+%Y_%m_%d-%H_%M_%S_%N")"
    __curr_date_yyyymm="$(date "+%Y%m")"
    __curr_date_yyyymmdd="$(date "+%Y%m%d")"
    __curr_uid="${__filename}.${__curr_processid}.${__curr_dateid}"

    __app_root_dir="${__dir%%/}/${PROCESS_NAME}"
    [[ -d  "${__app_root_dir}" ]] || mkdir -p "${__app_root_dir}"
# <<< Set magic variables for current file, directory, os etc. <<<


# >>> Parse parameters >>>
##############################################################################
    unset APP_NAME CURRENT_RUN_ENV PARAM_ENV_FILE DEBUG_MODE
    DEBUG_MODE="OFF"

    usage() { 
        echo "Usage: $0 [ -a app_name(mandatory, must be in lower case) ] [ -e current_run_env(mandatory, must be in lower case) ] [ -p PARAM_ENV_FILE(optional, if given file must exist) ] [ -d (optional switch, run in debug mode)] [ -h (optional switch, print usage) ] ..." 1>&2; 
        exit 1; 
    }

    while getopts ":a:e:p:vh" o; do
        case "${o}" in
            a)
                APP_NAME="${OPTARG}"
                [[ "${APP_NAME}" != "${APP_NAME,,}" ]] && { echo "ERROR: APP_NAME value must be in lower case" 1>&2; usage; }
                echo "APP_NAME IS SET TO: ${APP_NAME}"
                ;;
            e)
                CURRENT_RUN_ENV="${OPTARG}"
                [[ "${CURRENT_RUN_ENV}" != "${CURRENT_RUN_ENV,,}" ]] && { echo "ERROR: CURRENT_RUN_ENV value must be in lower case" 1>&2; usage; }
                echo "CURRENT_RUN_ENV IS SET TO: ${CURRENT_RUN_ENV}"
                ;;
            p)  
                PARAM_ENV_FILE="${OPTARG}"
                [[ -f "${PARAM_ENV_FILE}" ]] || { echo "ERROR: PARAM_ENV_FILE:'${PARAM_ENV_FILE}' not found" 1>&2; usage; }
                echo "PARAM_ENV_FILE IS SET TO: ${PARAM_ENV_FILE}"
                ;;
            d)  
                DEBUG_MODE="ON"
                echo "DEBUG_MODE IS TURNED ON"
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

    [[ ${APP_NAME+x} ]] || { echo "ERROR: APP_NAME is mandatory parameter"; usage; }

    [[ ${CURRENT_RUN_ENV+x} ]] || { echo "ERROR: CURRENT_RUN_ENV is mandatory parameter"; usage; }
# <<< Parse parameters <<<


# >>> Prepare runtime env using parameters >>>
##############################################################################
    # Set current batch id, generate new id if the batch file is not already present
    __batchid_dir="${__app_root_dir%%/}/app-batch-info/${APP_NAME}/${CURRENT_RUN_ENV}"
    [[ -d  "${__batchid_dir}" ]] || mkdir -p "${__batchid_dir}"
    __batchid_file="${__batchid_dir%%/}/current-batchid.conf"

    __is_set_batch_id="true"
    if [[ -s "${__batchid_file}" ]]
    then
        CURRENT_BATCH_ID="$( cat "${__batchid_file}" | sed -e '/^\s*$/d' -e '/\s*#.*$/d' | tail -1 )"
        if [[ "${CURRENT_BATCH_ID:-}" == "" ]]
        then
            export CURRENT_BATCH_ID="${__curr_date_yyyymmdd}"
            echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
        else
            __is_set_batch_id="false"
            export CURRENT_BATCH_ID="${CURRENT_BATCH_ID}"
        fi
    else
        export CURRENT_BATCH_ID="${__curr_date_yyyymmdd}"
        echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
    fi

    __log_dir="${__app_root_dir%%/}/app-log/${APP_NAME}/${CURRENT_RUN_ENV}/${__base}/${CURRENT_BATCH_ID}"
    [[ -d  "${__log_dir}" ]] || mkdir -p "${__log_dir}"
    __log_file="${__log_dir%%/}/${__curr_uid}.log"
    touch "${__log_file}"


    __tmp_dir="${__app_root_dir%%/}/app-tmp/${APP_NAME}/${CURRENT_RUN_ENV}/${__base}/${__curr_uid}.tmp-dir"
    [[ -d  "${__tmp_dir}" ]] || mkdir -p "${__tmp_dir}"

    __common_env_dir="${__app_root_dir%%/}/app-conf/common/${CURRENT_RUN_ENV}"
    __app_env_dir="${__app_root_dir%%/}/app-conf/${APP_NAME}/${CURRENT_RUN_ENV}"
    __script_env_dir="${__app_root_dir%%/}/app-conf/${APP_NAME}/${CURRENT_RUN_ENV}/${__base}"
    __param_env_dir="${__app_root_dir%%/}/app-param/${APP_NAME}/${CURRENT_RUN_ENV}"
    [[ -d  "${__common_env_dir}" ]] || mkdir -p "${__common_env_dir}"
    [[ -d  "${__app_env_dir}" ]] || mkdir -p "${__app_env_dir}"
    [[ -d  "${__script_env_dir}" ]] || mkdir -p "${__script_env_dir}"
    [[ -d  "${__param_env_dir}" ]] || mkdir -p "${__param_env_dir}"

    
     [[ ${PARAM_ENV_FILE+x} ]] || { echo "WARNING: PARAM_ENV_FILE not defined, using default"; PARAM_ENV_FILE="${__param_env_dir%%/}/${__base}.param.sh"; touch "${PARAM_ENV_FILE}"; }

     
# <<< Prepare runtime env using parameters <<<

# Define the environment variables (and their defaults) that this script depends on
LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected


# >>> Logging & Print Functions >>>
##############################################################################
    function __log () {
    local log_level="${1}"
    shift

    # shellcheck disable=SC2034
    local color_debug="\\x1b[35m"
    # shellcheck disable=SC2034
    local color_info="\\x1b[32m"
    # shellcheck disable=SC2034
    local color_notice="\\x1b[34m"
    # shellcheck disable=SC2034
    local color_warning="\\x1b[33m"
    # shellcheck disable=SC2034
    local color_error="\\x1b[31m"
    # shellcheck disable=SC2034
    local color_critical="\\x1b[1;31m"
    # shellcheck disable=SC2034
    local color_alert="\\x1b[1;37;41m"
    # shellcheck disable=SC2034
    local color_emergency="\\x1b[1;4;5;37;41m"

    local colorvar="color_${log_level}"

    local color="${!colorvar:-${color_error}}"
    local color_reset="\\x1b[0m"

    if [[ "${NO_COLOR:-}" = "true" ]] || { [[ "${TERM:-}" != "xterm"* ]] && [[ "${TERM:-}" != "screen"* ]]; } || [[ ! -t 2 ]]; then
        if [[ "${NO_COLOR:-}" != "false" ]]; then
        # Don't use colors on pipes or non-recognized terminals
        color=""; color_reset=""
        fi
    fi

    # all remaining arguments are to be printed
    local log_line=""

    while IFS=$'\n' read -r log_line; do
        echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") $(printf "[%9s]" "${log_level}") ${log_line}" >> "${__log_file}"
        echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}" 1>&2
    done <<< "${@:-}"
    }

    function emergency () {                                __log emergency "${@}"; exit 1; }
    function alert ()     { [[ "${LOG_LEVEL:-0}" -ge 1 ]] && __log alert "${@}"; true; }
    function critical ()  { [[ "${LOG_LEVEL:-0}" -ge 2 ]] && __log critical "${@}"; true; }
    function error ()     { [[ "${LOG_LEVEL:-0}" -ge 3 ]] && __log error "${@}"; true; }
    function warning ()   { [[ "${LOG_LEVEL:-0}" -ge 4 ]] && __log warning "${@}"; true; }
    function notice ()    { [[ "${LOG_LEVEL:-0}" -ge 5 ]] && __log notice "${@}"; true; }
    function info ()      { [[ "${LOG_LEVEL:-0}" -ge 6 ]] && __log info "${@}"; true; }
    function debug ()     { [[ "${LOG_LEVEL:-0}" -ge 7 ]] && __log debug "${@}"; true; }
# <<< Logging & Print Functions <<<


# >>> Signal trapping and backtracing >>>
##############################################################################
    function __cleanup_before_exit () {
        alert "Deleting the temp dir using the command: 'rm -fr ${__tmp_dir}'"
        rm -fr "${__tmp_dir}"
        info "Cleaning up. Done"
    }
    trap __cleanup_before_exit EXIT

    # requires `set -o errtrace`
    __err_report() {
        local error_code=${?}
        error "Error in ${__file} in function ${1} on line ${2}"
        exit ${error_code}
    }
    # Uncomment the following line for always providing an error backtrace
    trap '__err_report "${FUNCNAME:-.}" ${LINENO}' ERR

    if [[ "${DEBUG_MODE}" == "ON" ]]
    then
        echo "Starting process in DEBUG_MODE: ${DEBUG_MODE}"
        set -o xtrace
        PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
        LOG_LEVEL="7"
        # Enable error backtracing
        trap '__err_report "${FUNCNAME:-.}" ${LINENO}' ERR
    fi
# <<< Signal trapping and backtracing <<<


# >>> Print env info and source configs >>>
##############################################################################
[[ "${__is_set_batch_id}" == "true"  ]] && info "Setting CURRENT_BATCH_ID: ${CURRENT_BATCH_ID}"
export CURRENT_BATCH_ID="${CURRENT_BATCH_ID}"

info "__dir: ${__dir}"
info "__file: ${__file}"
info "__filename: ${__filename}"
info "__base: ${__base}"
info "__invocation: ${__invocation}"
info "__app_root_dir: ${__app_root_dir}"

info "__curr_processid: ${__curr_processid}"
info "__curr_dateid: ${__curr_dateid}"
info "__curr_date_yyyymm: ${__curr_date_yyyymm}"
info "__curr_date_yyyymmdd: ${__curr_date_yyyymmdd}"
info "__curr_uid: ${__curr_uid}"

info "__batchid_dir: ${__batchid_dir}"
info "__batchid_file: ${__batchid_file}"
info "__is_set_batch_id: ${__is_set_batch_id}"
info "__log_dir: ${__log_dir}"
info "__log_file: ${__log_file}"
info "__tmp_dir: ${__tmp_dir}"
info "__common_env_dir: ${__common_env_dir}"
info "__app_env_dir: ${__app_env_dir}"
info "__script_env_dir: ${__script_env_dir}"
info "__param_env_dir: ${__param_env_dir}"

info "APP_NAME: ${APP_NAME}"
info "CURRENT_RUN_ENV : ${CURRENT_RUN_ENV}"
info "PARAM_ENV_FILE : ${PARAM_ENV_FILE}"
info "DEBUG_MODE: ${DEBUG_MODE}"
info "CURRENT_BATCH_ID: ${CURRENT_BATCH_ID}"


# source common env 
for file in $(find "${__common_env_dir}" -maxdepth 1 -name '*.sh'); 
do
    notice "Sourcing file: '${file}' from __common_env_dir: '${__common_env_dir}'"
    source "${file}"; 
done

# source app specific envs
for file in $(find "${__app_env_dir}" -maxdepth 1 -name '*.sh'); 
do
    notice "Sourcing file: '${file}' from __app_env_dir: '${__app_env_dir}'"
    source "${file}"; 
done

# source script specific env
for file in $(find "${__script_env_dir}" -maxdepth 1 -name '*.sh'); 
do
    notice "Sourcing file: '${file}' from __script_env_dir: '${__script_env_dir}'"
    source "${file}"; 
done

# source param env
notice "Sourcing PARAM_ENV_FILE: '${PARAM_ENV_FILE}'"
source "${PARAM_ENV_FILE}"
# <<< Print env info and source configs <<<


# >>> Functions >>>
##############################################################################

# <<< Functions <<<

# >>> main >>>
##############################################################################

# <<< main <<<