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

# >>> Define container dictionaries for all variables used by the main script. >>>
##############################################################################
    # parameters passed to the script form the PARAM_ENV, this will be available for READ ONLY usage 
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A PARAM_ENV_READ_ONLY
    # config values once set in RUN_ENV will not change till end, this will be available for READ ONLY usage
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A RUN_ENV_READ_ONLY
    # Container for all configrations which can be set by the sourced config files. 
    # Any configration that is set by the sourced files must be set using function: setConfigEnv "key.name" "value"
    declare -A CONFIG_ENV
    # Env to track from where the value of a particular configration is being picked up
    declare -A CONFIG_ENV_REVISION_HISTORY
    # run env which are needed but are not supplied will be picked from CONFIG_ENV_DEFAULTS_READ_ONLY.
    # All values present in CONFIG_ENV_DEFAULTS_READ_ONLY will be looked up in CONFIG_ENV
    # if the value is not found in CONFIG_ENV then it will be picked from CONFIG_ENV_DEFAULTS_READ_ONLY.
    # this will be available for READ ONLY usage in all sourced scripts and should not be changed 
    # in any of the sourced scripts
    declare -A CONFIG_ENV_DEFAULTS_READ_ONLY
    # parameters passed to the script form the PARAM_ENV
    declare -A VAR_ENV
    # variables which remain constant during runtime form VAL_ENV
    declare -A VAl_ENV
# <<< Define container dictionaries for all variables used by the main script. <<<


# >>> Set magic variables for current file, directory, os etc. >>>
##############################################################################
    RUN_ENV_READ_ONLY["script.dir.path"]="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    RUN_ENV_READ_ONLY["script.file.path"]="${RUN_ENV_READ_ONLY["script.dir.path"]}/$(basename "${BASH_SOURCE[0]}")"
    RUN_ENV_READ_ONLY["script.file.name"]="$(basename "${RUN_ENV_READ_ONLY["script.file.path"]}")"
    RUN_ENV_READ_ONLY["script.file.ext"]="${RUN_ENV_READ_ONLY["script.file.name"]##*.}"
    RUN_ENV_READ_ONLY["script.file.base"]="$(basename "${RUN_ENV_READ_ONLY["script.file.name"]}" .${RUN_ENV_READ_ONLY["script.file.ext"]})"

    RUN_ENV_READ_ONLY["script.run.invocation"]="$(printf %q "${RUN_ENV_READ_ONLY["script.file.path"]}")$( (($#)) && printf ' %q' "$@" || true)"
    RUN_ENV_READ_ONLY["script.run.procid"]="$$"
    RUN_ENV_READ_ONLY["script.run.date"]="$(date)"
    RUN_ENV_READ_ONLY["script.run.whoami"]="$(whoami)"
    RUN_ENV_READ_ONLY["script.run.hostname"]="$(hostname)"
    RUN_ENV_READ_ONLY["script.run.dateid"]="$(date "+%Y_%m_%d-%H_%M_%S_%N")"
    RUN_ENV_READ_ONLY["script.run.date.yyyymm"]="$(date "+%Y%m")"
    RUN_ENV_READ_ONLY["script.run.date.yyyymmdd"]="$(date "+%Y%m%d")"
    RUN_ENV_READ_ONLY["script.run.unique.runid"]="${RUN_ENV_READ_ONLY["script.file.name"]}.${RUN_ENV_READ_ONLY["script.run.procid"]}.${RUN_ENV_READ_ONLY["script.run.dateid"]}"
# <<< Set magic variables for current file, directory, os etc. <<<


# >>> Parse parameters >>>
##############################################################################
    PARAM_ENV_READ_ONLY["script.debug.mode"]="OFF"
    PARAM_ENV_READ_ONLY["script.verbose.mode"]="OFF"
    

    usage() { 
        echo "Usage: $0 [ -p process_name(mandatory, all process dir will be created under process_name dir & process_name dir will be created under script.read.rootdir && script.write.rootdir) ] [ -a app_name(mandatory, must be in lower case) ] [ -e current_run_env(mandatory, must be in lower case) ] [ -c config_file_name(optional, if given file must exist) ] [ -d (optional switch, run in debug mode)] [ -v (optional switch, run in verbose mode)] [ -h (optional switch, print usage) ] ..." 1>&2; 
        exit 1; 
    }

    while getopts ":p:a:e:c:dvh" o; do
        case "${o}" in
            p)
                PARAM_ENV_READ_ONLY["script.process.name"]="${OPTARG}"

                echo "INFO: PARAM_ENV_READ_ONLY["script.process.name"] IS SET TO: ${PARAM_ENV_READ_ONLY["script.process.name"]}"
                ;;
            a)
                PARAM_ENV_READ_ONLY["script.process.appname"]="${OPTARG}"

                [[ "${PARAM_ENV_READ_ONLY["script.process.appname"]}" != "${PARAM_ENV_READ_ONLY["script.process.appname"],,}" ]] && { echo "ERROR: PARAM_ENV_READ_ONLY["script.process.appname"] value must be in lower case" 1>&2; usage; }
                
                echo "INFO: PARAM_ENV_READ_ONLY["script.process.appname"] IS SET TO: ${PARAM_ENV_READ_ONLY["script.process.appname"]}"
                ;;
            e)
                PARAM_ENV_READ_ONLY["script.runtime.envname"]="${OPTARG}"

                [[ "${PARAM_ENV_READ_ONLY["script.runtime.envname"]}" != "${PARAM_ENV_READ_ONLY["script.runtime.envname"],,}" ]] && { echo "ERROR: PARAM_ENV_READ_ONLY["script.runtime.envname"] value must be in lower case" 1>&2; usage; }

                echo "INFO: PARAM_ENV_READ_ONLY["script.runtime.envname"] IS SET TO: ${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
                ;;
            p)  
                PARAM_ENV_READ_ONLY["script.config.rootfile"]="${OPTARG}"

                [[ "$(dirname ${PARAM_ENV_READ_ONLY["script.config.rootfile"]})" == "." ]] && PARAM_ENV_READ_ONLY["script.config.rootfile"]="${RUN_ENV_READ_ONLY["script.dir.path"]%%/}/${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"

                [[ -f "${PARAM_ENV_READ_ONLY["script.config.rootfile"]}" ]] || { echo "ERROR: PARAM_ENV_READ_ONLY["script.config.rootfile"]:'${PARAM_ENV_READ_ONLY["script.config.rootfile"]}' not found" 1>&2; usage; }
                
                echo "INFO: PARAM_ENV_READ_ONLY["script.config.rootfile"] IS SET TO: ${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"
                ;;
            d)
                PARAM_ENV_READ_ONLY["script.debug.mode"]="ON"
                echo "INFO: PARAM_ENV_READ_ONLY["script.debug.mode"] IS SET TO: ${PARAM_ENV_READ_ONLY["script.debug.mode"]}"
                ;;
            v)  
                PARAM_ENV_READ_ONLY["script.verbose.mode"]="ON"
                
                echo "INFO: PARAM_ENV_READ_ONLY["script.verbose.mode"] IS SET TO: '${PARAM_ENV_READ_ONLY["script.verbose.mode"]}'"
                
                echo "WARNING: SETTING PARAM_ENV_READ_ONLY["script.verbose.mode"] TO: '${PARAM_ENV_READ_ONLY["script.verbose.mode"]} IS NOT RECOMMENDED FOR PRODUCTION RUNS. TURN VERBOSE MODE TO OFF IF NOT DOING TEST RUNS"

                echo "WARNING: PROCESS WILL HALT FOR 15 SECONDS BEFORE EXECUTION IN VERBOSE MODE RUNS"
                sleep 15
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

    [[ ${PARAM_ENV_READ_ONLY["script.process.name"]+x} ]] || { echo "ERROR: PARAM_ENV_READ_ONLY["script.process.name"] is mandatory parameter"; usage; }

    [[ ${PARAM_ENV_READ_ONLY["script.process.appname"]+x} ]] || { echo "ERROR: PARAM_ENV_READ_ONLY["script.process.appname"] is mandatory parameter"; usage; }

    [[ ${PARAM_ENV_READ_ONLY["script.runtime.envname"]+x} ]] || { echo "ERROR: PARAM_ENV_READ_ONLY["script.runtime.envname"] is mandatory parameter"; usage; }
# <<< Parse parameters <<<


# >>> Setup default config env for the process. >>>
##############################################################################
    CONFIG_ENV_DEFAULTS_READ_ONLY["script.config.root"]="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_ENV_DEFAULTS_READ_ONLY["script.config.root"]="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


    __app_root_dir="${RUN_ENV_READ_ONLY["script.dir.path"]%%/}/${PROCESS_NAME}"
        [[ -d  "${__app_root_dir}" ]] || mkdir -p "${__app_root_dir}"

# <<< Setup default config env for the process. <<<

# >>> Prepare runtime env using parameters >>>
##############################################################################
    # Set current batch id, generate new id if the batch file is not already present
    __batchid_dir="${__app_root_dir%%/}/app-batch-info/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
    [[ -d  "${__batchid_dir}" ]] || mkdir -p "${__batchid_dir}"
    __batchid_file="${__batchid_dir%%/}/current-batchid.conf"

    __is_set_batch_id="true"
    if [[ -s "${__batchid_file}" ]]
    then
        CURRENT_BATCH_ID="$( cat "${__batchid_file}" | sed -e '/^\s*$/d' -e '/\s*#.*$/d' | tail -1 )"
        if [[ "${CURRENT_BATCH_ID:-}" == "" ]]
        then
            export CURRENT_BATCH_ID="${RUN_ENV_READ_ONLY["script.run.date.yyyymmdd"]}"
            echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
        else
            __is_set_batch_id="false"
            export CURRENT_BATCH_ID="${CURRENT_BATCH_ID}"
        fi
    else
        export CURRENT_BATCH_ID="${RUN_ENV_READ_ONLY["script.run.date.yyyymmdd"]}"
        echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
    fi

    __log_dir="${__app_root_dir%%/}/app-log/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}/${RUN_ENV_READ_ONLY["script.file.base"]}/${CURRENT_BATCH_ID}"
    [[ -d  "${__log_dir}" ]] || mkdir -p "${__log_dir}"
    __log_file="${__log_dir%%/}/${RUN_ENV_READ_ONLY["script.run.uid"]}.log"
    touch "${__log_file}"


    __tmp_dir="${__app_root_dir%%/}/app-tmp/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}/${RUN_ENV_READ_ONLY["script.file.base"]}/${RUN_ENV_READ_ONLY["script.run.uid"]}.tmp-dir"
    [[ -d  "${__tmp_dir}" ]] || mkdir -p "${__tmp_dir}"

    __common_env_dir="${__app_root_dir%%/}/app-conf/common/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
    __app_env_dir="${__app_root_dir%%/}/app-conf/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
    __script_env_dir="${__app_root_dir%%/}/app-conf/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}/${RUN_ENV_READ_ONLY["script.file.base"]}"
    __param_env_dir="${__app_root_dir%%/}/app-param/${PARAM_ENV_READ_ONLY["script.process.appname"]}/${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
    [[ -d  "${__common_env_dir}" ]] || mkdir -p "${__common_env_dir}"
    [[ -d  "${__app_env_dir}" ]] || mkdir -p "${__app_env_dir}"
    [[ -d  "${__script_env_dir}" ]] || mkdir -p "${__script_env_dir}"
    [[ -d  "${__param_env_dir}" ]] || mkdir -p "${__param_env_dir}"

    
     [[ ${PARAM_ENV_READ_ONLY["script.config.rootfile"]+x} ]] || { echo "WARNING: PARAM_ENV_READ_ONLY["script.config.rootfile"] not defined, using default"; PARAM_ENV_READ_ONLY["script.config.rootfile"]="${__param_env_dir%%/}/${RUN_ENV_READ_ONLY["script.file.base"]}.param.sh"; touch "${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"; }

     
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
        error "Error in ${RUN_ENV_READ_ONLY["script.file.path"]} in function ${1} on line ${2}"
        exit ${error_code}
    }
    # Uncomment the following line for always providing an error backtrace
    trap '__err_report "${FUNCNAME:-.}" ${LINENO}' ERR

    if [[ "${PARAM_ENV_READ_ONLY["script.debug.mode"]}" == "ON" ]]
    then
        echo "Starting process in PARAM_ENV_READ_ONLY["script.debug.mode"]: ${PARAM_ENV_READ_ONLY["script.debug.mode"]}"
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

info "RUN_ENV_READ_ONLY["script.dir.path"]: ${RUN_ENV_READ_ONLY["script.dir.path"]}"
info "RUN_ENV_READ_ONLY["script.file.path"]: ${RUN_ENV_READ_ONLY["script.file.path"]}"
info "RUN_ENV_READ_ONLY["script.file.name"]: ${RUN_ENV_READ_ONLY["script.file.name"]}"
info "RUN_ENV_READ_ONLY["script.file.base"]: ${RUN_ENV_READ_ONLY["script.file.base"]}"
info "RUN_ENV_READ_ONLY["script.run.invocation"]: ${RUN_ENV_READ_ONLY["script.run.invocation"]}"
info "__app_root_dir: ${__app_root_dir}"

info "RUN_ENV_READ_ONLY["script.run.procid"]: ${RUN_ENV_READ_ONLY["script.run.procid"]}"
info "RUN_ENV_READ_ONLY["script.run.dateid"]: ${RUN_ENV_READ_ONLY["script.run.dateid"]}"
info "RUN_ENV_READ_ONLY["script.run.date.yyyymm"]: ${RUN_ENV_READ_ONLY["script.run.date.yyyymm"]}"
info "RUN_ENV_READ_ONLY["script.run.date.yyyymmdd"]: ${RUN_ENV_READ_ONLY["script.run.date.yyyymmdd"]}"
info "RUN_ENV_READ_ONLY["script.run.uid"]: ${RUN_ENV_READ_ONLY["script.run.uid"]}"

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

info "PARAM_ENV_READ_ONLY["script.process.appname"]: ${PARAM_ENV_READ_ONLY["script.process.appname"]}"
info "PARAM_ENV_READ_ONLY["script.runtime.envname"] : ${PARAM_ENV_READ_ONLY["script.runtime.envname"]}"
info "PARAM_ENV_READ_ONLY["script.config.rootfile"] : ${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"
info "PARAM_ENV_READ_ONLY["script.debug.mode"]: ${PARAM_ENV_READ_ONLY["script.debug.mode"]}"
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
notice "Sourcing PARAM_ENV_READ_ONLY["script.config.rootfile"]: '${PARAM_ENV_READ_ONLY["script.config.rootfile"]}'"
source "${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"
# <<< Print env info and source configs <<<


# >>> Functions >>>
##############################################################################

# <<< Functions <<<

# >>> main >>>
##############################################################################

# <<< main <<<