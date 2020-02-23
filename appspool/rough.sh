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