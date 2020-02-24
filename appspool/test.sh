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
    unset PARAM_ENV_READ_ONLY RUN_ENV_READ_ONLY CONFIG_ENV CONFIG_ENV_REVISION_HISTORY
    unset CONFIG_ENV_DEFAULTS_READ_ONLY VAR_ENV VAL_ENV
    
    # parameters passed to the script form the PARAM_ENV, this will be available for READ ONLY usage 
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A PARAM_ENV_READ_ONLY
    # config values once set in RUN_ENV will not change till end, this will be available for READ ONLY usage
    # in all sourced scripts and should not be changed in any of the sourced scripts
    declare -A RUN_ENV_READ_ONLY
    # Container for all configrations which can be set by the sourced config files. 
    # Any configration that is set by the sourced files must be set using function: add2ConfigEnv "key.name" "value"
    declare -A CONFIG_ENV
    # Env to track from where the value of a particular configration is being picked up
    declare -A CONFIG_ENV_REVISION_HISTORY
    # run env which are needed but are not supplied will be picked from CONFIG_ENV_DEFAULTS_READ_ONLY.
    # All values present in CONFIG_ENV_DEFAULTS_READ_ONLY will be looked up in CONFIG_ENV
    # if the value is not found in CONFIG_ENV then it will be picked from CONFIG_ENV_DEFAULTS_READ_ONLY.
    # this will be available for READ ONLY usage in all sourced scripts and should not be changed 
    # in any of the sourced scripts
    declare -A CONFIG_ENV_DEFAULTS_READ_ONLY
    # Env created by merging the CONFIG_ENV & CONFIG_ENV_DEFAULTS_READ_ONLY
    declare -A CONFIG_ENV_FINAL_READ_ONLY
    # parameters passed to the script form the PARAM_ENV
    declare -A VAR_ENV
    # variables which remain constant during runtime form VAL_ENV
    declare -A VAL_ENV
# <<< Define container dictionaries for all variables used by the main script. <<<


# >>> Set magic variables for current file, directory, os etc >>>
##############################################################################
    RUN_ENV_READ_ONLY["script.dir.path"]="$(cd "$(dirname "${BASH_SOURCE[${__tmp_source_idx:-0}]}")" && pwd)"
    RUN_ENV_READ_ONLY["script.file.path"]="${RUN_ENV_READ_ONLY["script.dir.path"]}/$(basename "${BASH_SOURCE[${__tmp_source_idx:-0}]}")"
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


# >>> Define usage and helptext >>>
##############################################################################
__sample_usage="SAMPLE USAGE: ${0} [ -p PROCESS_NAME ] [ -a app_name ] [ -e current_run_env ] [ -c config_file_name ] [ -d ] [ -v ] [ -h ] ..."

[[ "${__usage+_}" ]] || read -r -d '' __usage <<-'EOF'|| true # exits non-zero when EOF encountered
-p    PARAM_ENV_READ_ONLY["script.process.name"]       <<Mandatory parameter>>: Main process name. All process dir 
                                                         will be created under process_name dir & process_name dir 
                                                         will be created under script.read.rootdir && script.write.rootdir
                                                         defined in CONFIG_ENV.

  -a    PARAM_ENV_READ_ONLY["script.process.appname"]    <<Mandatory parameter>>: application name. Must be in lower case. 

  -e    PARAM_ENV_READ_ONLY["script.runtime.envname"]    <<Mandatory parameter>>: current run env name e.g dev/uat/prod. 
                                                         Must be in lower case.

  -c    PARAM_ENV_READ_ONLY["script.config.rootfile"]    <<Optional parameter>>: root config file name which will be used to
                                                         pass root configrations for the script run. NOT RECOMMEDED FOR PROD RUNS.

  -v    PARAM_ENV_READ_ONLY["script.verbose.mode"]       <<Optional parameter>>: Enable verbose mode, any standard error will be 
                                                         directed to screen instead of log file.
                                                         NOT RECOMMEDED FOR PROD RUNS. 

  -d    PARAM_ENV_READ_ONLY["script.debug.mode"]         <<Optional parameter>>: Enable debug mode, to be used only for dubugging. 
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
    PARAM_ENV_READ_ONLY["script.debug.mode"]="OFF"
    PARAM_ENV_READ_ONLY["script.verbose.mode"]="OFF"
    

    while getopts ":p:a:e:c:dvh" o; do
        case "${o}" in
            p)
                PARAM_ENV_READ_ONLY["script.process.name"]="${OPTARG}"

                echo "INFO: PARAM_ENV_READ_ONLY[script.process.name] IS SET TO: '${PARAM_ENV_READ_ONLY["script.process.name"]}'"
                ;;
            a)
                PARAM_ENV_READ_ONLY["script.process.appname"]="${OPTARG}"

                [[ "${PARAM_ENV_READ_ONLY["script.process.appname"]}" != "${PARAM_ENV_READ_ONLY["script.process.appname"],,}" ]] && { help "ERROR: PARAM_ENV_READ_ONLY[script.process.appname] value must be in lower case"; }
                
                echo "INFO: PARAM_ENV_READ_ONLY[script.process.appname] IS SET TO: '${PARAM_ENV_READ_ONLY["script.process.appname"]}'"
                ;;
            e)
                PARAM_ENV_READ_ONLY["script.runtime.envname"]="${OPTARG}"

                [[ "${PARAM_ENV_READ_ONLY["script.runtime.envname"]}" != "${PARAM_ENV_READ_ONLY["script.runtime.envname"],,}" ]] && { help "ERROR: PARAM_ENV_READ_ONLY[script.runtime.envname] value must be in lower case"; }

                echo "INFO: PARAM_ENV_READ_ONLY[script.runtime.envname] IS SET TO: '${PARAM_ENV_READ_ONLY["script.runtime.envname"]}'"
                ;;
            c)  
                PARAM_ENV_READ_ONLY["script.config.rootfile"]="${OPTARG}"

                [[ "$(dirname ${PARAM_ENV_READ_ONLY["script.config.rootfile"]})" == "." ]] && PARAM_ENV_READ_ONLY["script.config.rootfile"]="${RUN_ENV_READ_ONLY["script.dir.path"]%%/}/${PARAM_ENV_READ_ONLY["script.config.rootfile"]}"

                [[ -f "${PARAM_ENV_READ_ONLY["script.config.rootfile"]}" ]] || { help "ERROR: PARAM_ENV_READ_ONLY[script.config.rootfile]:'${PARAM_ENV_READ_ONLY["script.config.rootfile"]}' not found"; }
                
                echo "INFO: PARAM_ENV_READ_ONLY[script.config.rootfile] IS SET TO: '${PARAM_ENV_READ_ONLY["script.config.rootfile"]}'"
                ;;
            d)
                PARAM_ENV_READ_ONLY["script.debug.mode"]="ON"
                echo "INFO: PARAM_ENV_READ_ONLY[script.debug.mode] IS SET TO: '${PARAM_ENV_READ_ONLY["script.debug.mode"]}'"
                ;;
            v)  
                PARAM_ENV_READ_ONLY["script.verbose.mode"]="ON"
                
                echo "INFO: PARAM_ENV_READ_ONLY[script.verbose.mode] IS SET TO: '${PARAM_ENV_READ_ONLY["script.verbose.mode"]}'"
                
                echo "WARNING: SETTING PARAM_ENV_READ_ONLY[script.verbose.mode] TO: '${PARAM_ENV_READ_ONLY["script.verbose.mode"]}' IS NOT RECOMMENDED FOR PRODUCTION RUNS. TURN VERBOSE MODE TO OFF IF NOT DOING TEST RUNS"

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

    [[ ${PARAM_ENV_READ_ONLY["script.process.name"]+_} ]] || { help "ERROR: PARAM_ENV_READ_ONLY["script.process.name"] is mandatory parameter"; }

    [[ ${PARAM_ENV_READ_ONLY["script.process.appname"]+_} ]] || { help "ERROR: PARAM_ENV_READ_ONLY["script.process.appname"] is mandatory parameter"; }

    [[ ${PARAM_ENV_READ_ONLY["script.runtime.envname"]+_} ]] || { help "ERROR: PARAM_ENV_READ_ONLY["script.runtime.envname"] is mandatory parameter"; }

    PARAM_ENV_READ_ONLY["script.nonargs.paramlist"]="${@}"
    echo "INFO: ALL REMAINING PARAMS ARE LOADED TO PARAM_ENV_READ_ONLY[script.nonargs.paramlist] ARE: '${PARAM_ENV_READ_ONLY["script.nonargs.paramlist"]}'"
# <<< Parse parameters. <<<


# >>> Setup default config env for the process >>>
##############################################################################
    CONFIG_ENV_DEFAULTS_READ_ONLY["script.read.rootdir"]="${RUN_ENV_READ_ONLY["script.dir.path"]%%/}/${PARAM_ENV_READ_ONLY["script.process.name"]}"
    CONFIG_ENV_DEFAULTS_READ_ONLY["script.write.rootdir"]="${RUN_ENV_READ_ONLY["script.dir.path"]%%/}/${PARAM_ENV_READ_ONLY["script.process.name"]}"
# <<< Setup default config env for the process. <<<

# >>> Functions for setting and merging configs >>>
##############################################################################
        add2ConfigEnv() {
        local keyname="${1}"
        local value="${2}"
        local caller_script="$(caller | cut -d' ' -f2-)"

        if [[ ${CONFIG_ENV_DEFAULTS_READ_ONLY[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_ENV[${keyname}]+_} ]]
            then
                CONFIG_ENV_REVISION_HISTORY[${keyname}]="${CONFIG_ENV_REVISION_HISTORY[${keyname}]} => ${caller_script}@add2ConfigEnv '${keyname}' '${value}'"
            else
                CONFIG_ENV_REVISION_HISTORY[${keyname}]="CONFIG_ENV_DEFAULTS_READ_ONLY[${keyname}] => ${caller_script}@add2ConfigEnv '${keyname}' '${value}'"
            fi

            CONFIG_ENV[${keyname}]="${value}"
        else
            echo "WARNING: SKIPPING config addition to env for config: '${keyname}' as only configs for which defaults are set can be used within the process"
        fi
    }

    refreshFinalConfigEnv() {
        for k in "${!CONFIG_ENV_DEFAULTS_READ_ONLY[@]}"
        do
            if [[ ${CONFIG_ENV[${k}]+_} ]]
            then
                CONFIG_ENV_FINAL_READ_ONLY[${k}]="${CONFIG_ENV[${k}]}"
            else
                CONFIG_ENV_FINAL_READ_ONLY[${k}]="${CONFIG_ENV_DEFAULTS_READ_ONLY[${k}]}"
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
# <<< Functions for setting and merging configs. <<<

add2ConfigEnv 'script.read.rootdir2' 'check'
add2ConfigEnv 'script.read.rootdir4' 'check2'

source test2.sh

refreshFinalConfigEnv
showConfigs PARAM_ENV_READ_ONLY
showConfigs RUN_ENV_READ_ONLY
showConfigs CONFIG_ENV_FINAL_READ_ONLY
showConfigs CONFIG_ENV_REVISION_HISTORY
showConfigs CONFIG_ENV_DEFAULTS_READ_ONLY

# unset PARAM_ENV_READ_ONLY RUN_ENV_READ_ONLY CONFIG_ENV CONFIG_ENV_REVISION_HISTORY
# unset CONFIG_ENV_DEFAULTS_READ_ONLY VAR_ENV VAL_ENV