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

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    __i_am_main_script="0" # false

    if [[ "${__usage+_}" ]]; then
        if [[ "${BASH_SOURCE[1]}" = "${0}" ]]; then
            __i_am_main_script="1" # true
        fi

        __external_usage="true"
        __tmp_source_idx=1
    fi
else
    __i_am_main_script="1" # true
    [[ "${__usage+_}" ]] && unset -v __usage
    [[ "${__helptext+_}" ]] && unset -v __helptext
fi


# >>> Define container dictionaries for all variables used by the main script >>>
##############################################################################
    unset PARAM_ENV RUN_ENV CONFIG_ADD_ENV CONFIG_ENV_REVISION_HISTORY
    unset CONFIG_DEFAULTS_ENV VAR_ENV VAL_ENV
    
    # parameters passed to the script form the PARAM_ENV, this will be available for READ ONLY usage 
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A PARAM_ENV
    # config values once set in RUN_ENV will not change till end, this will be available for READ ONLY usage
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A RUN_ENV
    # Container for all configrations which can be set by the sourced config files. 
    # Any configration that is set by the sourced files must be set using function: add2ConfigEnv "key.name" "value"
    declare -A CONFIG_ADD_ENV
    # Env to track from where the value of a particular configration is being picked up
    declare -A CONFIG_ENV_REVISION_HISTORY
    # run env which are needed but are not supplied will be picked from CONFIG_DEFAULTS_ENV.
    # All values present in CONFIG_DEFAULTS_ENV will be looked up in CONFIG_ADD_ENV
    # if the value is not found in CONFIG_ADD_ENV then it will be picked from CONFIG_DEFAULTS_ENV.
    # this will be available for READ ONLY usage in all sourced scripts and should not be changed 
    # in any of the sourced scripts
    declare -A CONFIG_DEFAULTS_ENV
    # Env created by merging the CONFIG_ADD_ENV & CONFIG_DEFAULTS_ENV
    declare -A CONFIG_ENV
    # parameters passed to the script form the PARAM_ENV
    declare -A VAR_ENV

    # below dictionaries will be used to define dynamic templates
    # these templates can use variables from RUN_ENV, PARAM_ENV, CONFIG_ENV & VAR_ENV
    declare -A DYNAMIC_TEMPLATE_DEFAULT_ENV
    declare -A DYNAMIC_TEMPLATE_ENV
    declare -A DYNAMIC_TEMPLATE_ENV_REVISION_HISTORY
# <<< Define container dictionaries for all variables used by the main script. <<<


# >>> Set magic variables for current file, directory, os etc >>>
##############################################################################
    RUN_ENV["script.dir.path"]="$(cd "$(dirname "${BASH_SOURCE[${__tmp_source_idx:-0}]}")" && pwd)"
    RUN_ENV["script.file.path"]="${RUN_ENV["script.dir.path"]}/$(basename "${BASH_SOURCE[${__tmp_source_idx:-0}]}")"
    RUN_ENV["script.file.name"]="$(basename "${RUN_ENV["script.file.path"]}")"
    RUN_ENV["script.file.ext"]="${RUN_ENV["script.file.name"]##*.}"
    RUN_ENV["script.file.base"]="$(basename "${RUN_ENV["script.file.name"]}" .${RUN_ENV["script.file.ext"]})"

    RUN_ENV["script.run.invocation"]="$(printf %q "${RUN_ENV["script.file.path"]}")$( (($#)) && printf ' %q' "$@" || true)"
    RUN_ENV["script.run.procid"]="$$"
    RUN_ENV["script.run.date"]="$(date)"
    RUN_ENV["script.run.whoami"]="$(whoami)"
    RUN_ENV["script.run.hostname"]="$(hostname)"
    RUN_ENV["script.run.dateid"]="$(date "+%Y_%m_%d-%H_%M_%S_%N")"
    RUN_ENV["script.run.date.yyyymm"]="$(date "+%Y%m")"
    RUN_ENV["script.run.date.yyyymmdd"]="$(date "+%Y%m%d")"
    RUN_ENV["script.run.unique.runid"]="${RUN_ENV["script.file.name"]}.${RUN_ENV["script.run.procid"]}.${RUN_ENV["script.run.dateid"]}"
# <<< Set magic variables for current file, directory, os etc. <<<


# >>> Define usage and helptext >>>
##############################################################################
__sample_usage="SAMPLE USAGE: ${0} [ -p PROCESS_NAME ] [ -a app_name ] [ -e current_run_env ] [ -c config_file_name ] [ -d ] [ -v ] [ -h ] ..."

[[ "${__usage+_}" ]] || read -r -d '' __usage <<-'EOF'|| true # exits non-zero when EOF encountered
-p    PARAM_ENV["script.process.name"]       <<Mandatory parameter>>: Main process name. All process dir 
                                                         will be created under process_name dir & process_name dir 
                                                         will be created under script.read.rootdir && script.write.rootdir
                                                         defined in CONFIG_ADD_ENV.

  -a    PARAM_ENV["script.process.appname"]    <<Mandatory parameter>>: application name. Must be in lower case. 

  -e    PARAM_ENV["script.runtime.envname"]    <<Mandatory parameter>>: current run env name e.g dev/uat/prod. 
                                                         Must be in lower case.

  -c    PARAM_ENV["script.config.rootfile"]    <<Optional parameter>>: root config file name which will be used to
                                                         pass root configrations for the script run. NOT RECOMMEDED FOR PROD RUNS.

  -v    PARAM_ENV["script.verbose.mode"]       <<Optional parameter>>: Enable verbose mode, any standard error will be 
                                                         directed to screen instead of log file.
                                                         NOT RECOMMEDED FOR PROD RUNS. 

  -d    PARAM_ENV["script.debug.mode"]         <<Optional parameter>>: Enable debug mode, to be used only for dubugging. 
                                                         NOT RECOMMEDED FOR PROD RUNS.

  -h    --help                                           This page
EOF

    # shellcheck disable=SC2015
    [[ "${__helptext+_}" ]] || read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
    Generic script for triggering main jobs.
EOF


    function help () {
        echo "" 1>&2
        echo " ${*}" 1>&2
        echo "" 1>&2
        echo " ${__sample_usage}"
        echo "" 1>&2
        echo "  ${__usage:-No usage available}" 1>&2
        echo "" 1>&2

        if [[ "${__helptext:-}" ]]; then
            echo " ${__helptext}" 1>&2
            echo "" 1>&2
        fi

        exit 1
    }
# <<< Define usage and helptext. <<<


# >>> Parse parameters >>>
##############################################################################
    PARAM_ENV["script.debug.mode"]="OFF"
    PARAM_ENV["script.verbose.mode"]="OFF"
    

    while getopts ":p:a:e:c:dvh" o; do
        case "${o}" in
            p)
                PARAM_ENV["script.process.name"]="${OPTARG}"

                echo "INFO: PARAM_ENV[script.process.name] IS SET TO: '${PARAM_ENV["script.process.name"]}'"
                ;;
            a)
                PARAM_ENV["script.process.appname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.process.appname"]}" != "${PARAM_ENV["script.process.appname"],,}" ]] && { help "ERROR: PARAM_ENV[script.process.appname] value must be in lower case"; }
                
                echo "INFO: PARAM_ENV[script.process.appname] IS SET TO: '${PARAM_ENV["script.process.appname"]}'"
                ;;
            e)
                PARAM_ENV["script.runtime.envname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.runtime.envname"]}" != "${PARAM_ENV["script.runtime.envname"],,}" ]] && { help "ERROR: PARAM_ENV[script.runtime.envname] value must be in lower case"; }

                echo "INFO: PARAM_ENV[script.runtime.envname] IS SET TO: '${PARAM_ENV["script.runtime.envname"]}'"
                ;;
            c)  
                PARAM_ENV["script.config.rootfile"]="${OPTARG}"

                [[ "$(dirname ${PARAM_ENV["script.config.rootfile"]})" == "." ]] && PARAM_ENV["script.config.rootfile"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.config.rootfile"]}"

                [[ -f "${PARAM_ENV["script.config.rootfile"]}" ]] || { help "ERROR: PARAM_ENV[script.config.rootfile]:'${PARAM_ENV["script.config.rootfile"]}' not found"; }
                
                echo "INFO: PARAM_ENV[script.config.rootfile] IS SET TO: '${PARAM_ENV["script.config.rootfile"]}'"
                ;;
            d)
                PARAM_ENV["script.debug.mode"]="ON"
                echo "INFO: PARAM_ENV[script.debug.mode] IS SET TO: '${PARAM_ENV["script.debug.mode"]}'"
                ;;
            v)  
                PARAM_ENV["script.verbose.mode"]="ON"
                
                echo "INFO: PARAM_ENV[script.verbose.mode] IS SET TO: '${PARAM_ENV["script.verbose.mode"]}'"
                
                echo "WARNING: SETTING PARAM_ENV[script.verbose.mode] TO: '${PARAM_ENV["script.verbose.mode"]}' IS NOT RECOMMENDED FOR PRODUCTION RUNS. TURN VERBOSE MODE TO OFF IF NOT DOING TEST RUNS"

                echo "WARNING: PROCESS WILL HALT FOR 15 SECONDS BEFORE EXECUTION IN VERBOSE MODE RUNS"
                sleep 15
                ;;
            h)  
                help "Help using ${0}"
                ;;
            :)  
                help "ERROR: Option -$OPTARG requires an argument"
                ;;
            \?)
                help "ERROR: Invalid option -$OPTARG"
                ;;
        esac
    done

    shift $((OPTIND-1))

    [[ ${PARAM_ENV["script.process.name"]+_} ]] || { help "ERROR: PARAM_ENV["script.process.name"] is mandatory parameter"; }

    [[ ${PARAM_ENV["script.process.appname"]+_} ]] || { help "ERROR: PARAM_ENV["script.process.appname"] is mandatory parameter"; }

    [[ ${PARAM_ENV["script.runtime.envname"]+_} ]] || { help "ERROR: PARAM_ENV["script.runtime.envname"] is mandatory parameter"; }

    PARAM_ENV["script.nonargs.paramlist"]="${@}"
    echo "INFO: ALL REMAINING PARAMS ARE LOADED TO PARAM_ENV[script.nonargs.paramlist] ARE: '${PARAM_ENV["script.nonargs.paramlist"]}'"
# <<< Parse parameters. <<<


# >>> Setup default config env for the process >>>
# Only these config overrides will get picked from the env
# So if default is not available but we still want to pick 
# from env then a NULL must be specified e.g CONFIG_DEFAULTS_ENV["script.conf.unknown"]="NULL"
##############################################################################
    CONFIG_DEFAULTS_ENV["script.read.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"
    
    CONFIG_DEFAULTS_ENV["script.write.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"
# <<< Setup default config env for the process. <<<


# >>> Setup default for dynamic templates >>>
# Only these dynamic template overrides will get picked from the env
# So if default is not available but we still want to pick 
# from env then a NULL must be specified e.g DYNAMIC_TEMPLATE_DEFAULT_ENV["script.template.unknown"]="NULL"
##############################################################################
    DYNAMIC_TEMPLATE_DEFAULT_ENV["script.template.unknown"]="NULL"
# <<< Setup default for dynamic templates. <<<


# >>> Functions for setting, merging & resolving configs & dynamic templates >>>
##############################################################################
    add2DynamicTemplateEnv() {
        local keyname="${1}"
        local value="${2}"
        local caller_script="$(caller | cut -d' ' -f2-)"

        if [[ ${DYNAMIC_TEMPLATE_DEFAULT_ENV[${keyname}]+_} ]]
        then
            if [[ ${DYNAMIC_TEMPLATE_ENV[${keyname}]+_} ]]
            then
                DYNAMIC_TEMPLATE_ENV_REVISION_HISTORY[${keyname}]="${DYNAMIC_TEMPLATE_ENV_REVISION_HISTORY[${keyname}]} => ${caller_script}@add2DynamicTemplateEnv '${keyname}' '${value}'"
            else
                DYNAMIC_TEMPLATE_ENV_REVISION_HISTORY[${keyname}]="DYNAMIC_TEMPLATE_DEFAULT_ENV[${keyname}] => ${caller_script}@add2DynamicTemplateEnv '${keyname}' '${value}'"
            fi

            DYNAMIC_TEMPLATE_ENV[${keyname}]="${value}"
        else
            echo "WARNING: SKIPPING dynamic template addition to env for template: '${keyname}' as only templates for which defaults are set can be used within the process"
        fi
    }

    add2ConfigEnv() {
        local keyname="${1}"
        local value="${2}"
        local caller_script="$(caller | cut -d' ' -f2-)"

        if [[ ${CONFIG_DEFAULTS_ENV[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_ADD_ENV[${keyname}]+_} ]]
            then
                CONFIG_ENV_REVISION_HISTORY[${keyname}]="${CONFIG_ENV_REVISION_HISTORY[${keyname}]} => ${caller_script}@add2ConfigEnv '${keyname}' '${value}'"
            else
                CONFIG_ENV_REVISION_HISTORY[${keyname}]="CONFIG_DEFAULTS_ENV[${keyname}] => ${caller_script}@add2ConfigEnv '${keyname}' '${value}'"
            fi

            CONFIG_ADD_ENV[${keyname}]="${value}"
        else
            echo "WARNING: SKIPPING config addition to env for config: '${keyname}' as only configs for which defaults are set can be used within the process"
        fi
    }

    refreshFinalConfigEnv() {
        for k in "${!CONFIG_DEFAULTS_ENV[@]}"
        do
            if [[ ${CONFIG_ADD_ENV[${k}]+_} ]]
            then
                CONFIG_ENV[${k}]="${CONFIG_ADD_ENV[${k}]}"
            else
                CONFIG_ENV[${k}]="${CONFIG_DEFAULTS_ENV[${k}]}"
            fi
        done
    }

    # TO BE DEFINED AFTER LOG FILE DEFINITION
    showConfigs() {
        local container_name="${1}"
        echo -e "\n# Begin show configs: ${container_name} >>>"
        for k in $(eval echo "\${!${container_name}[@]}")
        do
            echo -e "\t INFO: ${container_name}[${k}]='$(eval echo "\${${container_name}[${k}]}")'"
        done
        echo -e "# End show configs: ${container_name} <<<\n"
    }
# <<< Functions for setting, merging & resolving configs & dynamic templates. <<<



# >>> Prepare runtime env using parameters >>>
##############################################################################
    # Set current batch id, generate new id if the batch file is not already present
    __batchid_dir="${__app_root_dir%%/}/app-batch-info/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}"
    [[ -d  "${__batchid_dir}" ]] || mkdir -p "${__batchid_dir}"
    __batchid_file="${__batchid_dir%%/}/current-batchid.conf"

    __is_set_batch_id="true"
    if [[ -s "${__batchid_file}" ]]
    then
        CURRENT_BATCH_ID="$( cat "${__batchid_file}" | sed -e '/^\s*$/d' -e '/\s*#.*$/d' | tail -1 )"
        if [[ "${CURRENT_BATCH_ID:-}" == "" ]]
        then
            export CURRENT_BATCH_ID="${RUN_ENV["script.run.date.yyyymmdd"]}"
            echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
        else
            __is_set_batch_id="false"
            export CURRENT_BATCH_ID="${CURRENT_BATCH_ID}"
        fi
    else
        export CURRENT_BATCH_ID="${RUN_ENV["script.run.date.yyyymmdd"]}"
        echo "${CURRENT_BATCH_ID}" > "${__batchid_file}"
    fi

    __log_dir="${__app_root_dir%%/}/app-log/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.file.base"]}/${CURRENT_BATCH_ID}"
    [[ -d  "${__log_dir}" ]] || mkdir -p "${__log_dir}"
    __log_file="${__log_dir%%/}/${RUN_ENV["script.run.uid"]}.log"
    touch "${__log_file}"


    __tmp_dir="${__app_root_dir%%/}/app-tmp/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.file.base"]}/${RUN_ENV["script.run.uid"]}.tmp-dir"
    [[ -d  "${__tmp_dir}" ]] || mkdir -p "${__tmp_dir}"

    __common_env_dir="${__app_root_dir%%/}/app-conf/common/${PARAM_ENV["script.runtime.envname"]}"
    __app_env_dir="${__app_root_dir%%/}/app-conf/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}"
    __script_env_dir="${__app_root_dir%%/}/app-conf/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.file.base"]}"
    __param_env_dir="${__app_root_dir%%/}/app-param/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}"
    [[ -d  "${__common_env_dir}" ]] || mkdir -p "${__common_env_dir}"
    [[ -d  "${__app_env_dir}" ]] || mkdir -p "${__app_env_dir}"
    [[ -d  "${__script_env_dir}" ]] || mkdir -p "${__script_env_dir}"
    [[ -d  "${__param_env_dir}" ]] || mkdir -p "${__param_env_dir}"

    
     [[ ${PARAM_ENV["script.config.rootfile"]+_} ]] || { echo "WARNING: PARAM_ENV["script.config.rootfile"] not defined, using default"; PARAM_ENV["script.config.rootfile"]="${__param_env_dir%%/}/${RUN_ENV["script.file.base"]}.param.sh"; touch "${PARAM_ENV["script.config.rootfile"]}"; }

     
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
        error "Error in ${RUN_ENV["script.file.path"]} in function ${1} on line ${2}"
        exit ${error_code}
    }
    # Uncomment the following line for always providing an error backtrace
    trap '__err_report "${FUNCNAME:-.}" ${LINENO}' ERR

    if [[ "${PARAM_ENV["script.debug.mode"]}" == "ON" ]]
    then
        echo "Starting process in PARAM_ENV["script.debug.mode"]: ${PARAM_ENV["script.debug.mode"]}"
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

info "RUN_ENV["script.dir.path"]: ${RUN_ENV["script.dir.path"]}"
info "RUN_ENV["script.file.path"]: ${RUN_ENV["script.file.path"]}"
info "RUN_ENV["script.file.name"]: ${RUN_ENV["script.file.name"]}"
info "RUN_ENV["script.file.base"]: ${RUN_ENV["script.file.base"]}"
info "RUN_ENV["script.run.invocation"]: ${RUN_ENV["script.run.invocation"]}"
info "__app_root_dir: ${__app_root_dir}"

info "RUN_ENV["script.run.procid"]: ${RUN_ENV["script.run.procid"]}"
info "RUN_ENV["script.run.dateid"]: ${RUN_ENV["script.run.dateid"]}"
info "RUN_ENV["script.run.date.yyyymm"]: ${RUN_ENV["script.run.date.yyyymm"]}"
info "RUN_ENV["script.run.date.yyyymmdd"]: ${RUN_ENV["script.run.date.yyyymmdd"]}"
info "RUN_ENV["script.run.uid"]: ${RUN_ENV["script.run.uid"]}"

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

info "PARAM_ENV["script.process.appname"]: ${PARAM_ENV["script.process.appname"]}"
info "PARAM_ENV["script.runtime.envname"] : ${PARAM_ENV["script.runtime.envname"]}"
info "PARAM_ENV["script.config.rootfile"] : ${PARAM_ENV["script.config.rootfile"]}"
info "PARAM_ENV["script.debug.mode"]: ${PARAM_ENV["script.debug.mode"]}"
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
notice "Sourcing PARAM_ENV["script.config.rootfile"]: '${PARAM_ENV["script.config.rootfile"]}'"
source "${PARAM_ENV["script.config.rootfile"]}"
# <<< Print env info and source configs <<<


# >>> Functions >>>
##############################################################################

# <<< Functions <<<

# >>> main >>>
##############################################################################

# <<< main <<<