#!/usr/bin/env bash

# Reference & Lot Of The Functionality Is Taken From: https://bash3boilerplate.sh/ && Multiple Online Resources. 
# Thanks To The Community!!

# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit On Error Inside Any Functions Or Subshells.
set -o errtrace
# Do Not Allow Use Of Undefined Vars. Use ${VAR:-} To Use An Undefined VAR
set -o nounset
# Catch The Error In Case Mysqldump Fails (But Gzip Succeeds) In `mysqldump |gzip`
set -o pipefail
# Turn On Traces, Useful While Debugging But Commented Out By Default
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


# >>> Define Container Dictionaries For All Variables Used By The Main Script >>>
##############################################################################
    unset PARAM_ENV RUN_ENV CONFIG_ADD_ENV CONFIG_ENV_LINEAGE
    unset CONFIG_DEFAULTS_ENV CONFIG_EVAL_LINEAGE VAR_ENV
    
    # Parameters Passed To The Script Form The PARAM_ENV, This Will Be Available For Read Only Usage 
    # In All Sourced Scripts And Should Not Be Changed In Any Of The Sourced Scripts
    declare -A PARAM_ENV
    # Config Values Once Set In RUN_ENV Will Not Change Till End, This Will Be Available For READ ONLY Usage
    # In All Sourced Scripts And Should Not Be Changed In Any Of The Sourced Scripts
    declare -A RUN_ENV
    # Container For All Configrations Which Can Be Set By The Sourced Config Files. 
    # Any Configration That Is Set By The Sourced Files Must Be Set Using Function: add2ConfigEnv "key.name" "value"
    declare -A CONFIG_ADD_ENV
    # Env To Track From Where The Value Of A Particular Configration Is Being Picked Up
    declare -A CONFIG_ENV_LINEAGE
    # Run Env Which Are Needed But Are Not Supplied Will Be Picked From CONFIG_DEFAULTS_ENV.
    # All Values Present In CONFIG_DEFAULTS_ENV Will Be Looked Up In CONFIG_ADD_ENV
    # If The Value Is Not Found In CONFIG_ADD_ENV Then It Will Be Picked From CONFIG_DEFAULTS_ENV.
    # This Will Be Available For Read Only Usage In All Sourced Scripts And Should Not Be Changed 
    # In Any Of The Sourced Scripts
    declare -A CONFIG_DEFAULTS_ENV
    # Env Created By Merging The CONFIG_ADD_ENV & CONFIG_DEFAULTS_ENV
    declare -A CONFIG_ENV
    # Env Containing Lineage Of Evalautions On A Keys
    declare -A CONFIG_EVAL_LINEAGE
    # Env Containing Evalauted Config Values
    declare -A CONFIG_EVAL_ENV
    # Env Created For Variables Used Within The Script
    declare -A VAR_ENV
# <<< Define Container Dictionaries For All Variables Used By The Main Script. <<<


# >>> Set Magic Variables For Current File, Directory, OS etc >>>
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
# <<< Set Magic Variables For Current File, Directory, OS etc. <<<


# >>> Define Usage And Helptext >>>
##############################################################################
__sample_usage="SAMPLE USAGE: ${0} [ -p PROCESS_NAME ] [ -a app_name ] [ -e current_run_env ] [ -c config_file_name ] [ -d ] [ -v ] [ -h ] ..."

[[ "${__usage+_}" ]] || read -r -d '' __usage <<-'EOF'|| true # exits non-zero when EOF encountered
-p    PARAM_ENV["script.process.name"]       <<Mandatory Parameter>>: Main Process Name. All Process Dir 
                                             Will Be Created Under process_name dir & process_name Dir 
                                             Will Be Created Under script.read.rootdir & script.write.rootdir
                                             Defined In CONFIG_ADD_ENV.

  -a    PARAM_ENV["script.process.appname"]    <<Mandatory Parameter>>: Application Name. Must Be In Lower Case. 

  -e    PARAM_ENV["script.runtime.envname"]    <<Mandatory Parameter>>: Current Run Env Name e.g. dev/uat/prod. 
                                               Must Be In Lower Case.

  -c    PARAM_ENV["script.config.rootfile"]    <<Optional Parameter>>: Root Config File Name Which Will Be Used To
                                               Pass Root Configrations For The Script Run. NOT RECOMMEDED FOR PROD RUNS.

  -v    PARAM_ENV["script.verbose.mode"]       <<Optional Parameter>>: Enable Verbose Mode, Any Standard Error Will Be 
                                               Directed To Screen Instead Of Log File. NOT RECOMMEDED FOR PROD RUNS. 

  -d    PARAM_ENV["script.debug.mode"]         <<Optional Parameter>>: Enable Debug Mode, To Be Used Only For Dubugging. 
                                               NOT RECOMMEDED FOR PROD RUNS.

  -h    --help                                 This Page
EOF

    # shellcheck disable=SC2015
    [[ "${__helptext+_}" ]] || read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
    Generic Script For Triggering Main Jobs.
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
# <<< Define Usage And Helptext. <<<


# >>> Parse Parameters >>>
##############################################################################
    PARAM_ENV["script.debug.mode"]="OFF"
    PARAM_ENV["script.verbose.mode"]="OFF"
    

    while getopts ":p:a:e:c:dvh" o; do
        case "${o}" in
            p)
                PARAM_ENV["script.process.name"]="${OPTARG}"

                echo "INFO: PARAM_ENV[script.process.name] Is Set To: '${PARAM_ENV["script.process.name"]}'"
                ;;
            a)
                PARAM_ENV["script.process.appname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.process.appname"]}" != "${PARAM_ENV["script.process.appname"],,}" ]] && { help "ERROR: PARAM_ENV[script.process.appname] Value Must Be In Lower Case"; }
                
                echo "INFO: PARAM_ENV[script.process.appname] Is Set To: '${PARAM_ENV["script.process.appname"]}'"
                ;;
            e)
                PARAM_ENV["script.runtime.envname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.runtime.envname"]}" != "${PARAM_ENV["script.runtime.envname"],,}" ]] && { help "ERROR: PARAM_ENV[script.runtime.envname] Value Must Be In Lower Case"; }

                echo "INFO: PARAM_ENV[script.runtime.envname] Is Set To: '${PARAM_ENV["script.runtime.envname"]}'"
                ;;
            c)  
                PARAM_ENV["script.config.rootfile"]="${OPTARG}"

                [[ "$(dirname ${PARAM_ENV["script.config.rootfile"]})" == "." ]] && PARAM_ENV["script.config.rootfile"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.config.rootfile"]}"

                [[ -f "${PARAM_ENV["script.config.rootfile"]}" ]] || { help "ERROR: PARAM_ENV[script.config.rootfile]:'${PARAM_ENV["script.config.rootfile"]}' Not Found"; }
                
                echo "INFO: PARAM_ENV[script.config.rootfile] Is Set To: '${PARAM_ENV["script.config.rootfile"]}'"
                ;;
            d)
                PARAM_ENV["script.debug.mode"]="ON"
                echo "INFO: PARAM_ENV[script.debug.mode] Is Set To: '${PARAM_ENV["script.debug.mode"]}'"
                ;;
            v)  
                PARAM_ENV["script.verbose.mode"]="ON"
                
                echo "INFO: PARAM_ENV[script.verbose.mode] Is Set To: '${PARAM_ENV["script.verbose.mode"]}'"
                
                echo "WARNING: SETTING PARAM_ENV[script.verbose.mode] TO: '${PARAM_ENV["script.verbose.mode"]}' IS NOT RECOMMENDED FOR PRODUCTION RUNS. TURN VERBOSE MODE TO OFF IF NOT DOING TEST RUNS"

                echo "WARNING: PROCESS WILL HALT FOR 15 SECONDS BEFORE EXECUTION IN VERBOSE MODE RUNS"
                sleep 15
                ;;
            h)  
                help "Help Using ${0}"
                ;;
            :)  
                help "ERROR: Option -$OPTARG Requires An Argument"
                ;;
            \?)
                help "ERROR: Invalid Option -$OPTARG"
                ;;
        esac
    done

    shift $((OPTIND-1))

    [[ ${PARAM_ENV["script.process.name"]+_} ]] || { help "ERROR: PARAM_ENV["script.process.name"] Is Mandatory Parameter"; }

    [[ ${PARAM_ENV["script.process.appname"]+_} ]] || { help "ERROR: PARAM_ENV["script.process.appname"] Is Mandatory Parameter"; }

    [[ ${PARAM_ENV["script.runtime.envname"]+_} ]] || { help "ERROR: PARAM_ENV["script.runtime.envname"] Is Mandatory Parameter"; }

    PARAM_ENV["script.nonargs.paramlist"]="${@}"
    echo "INFO: All Remaining Params Are Loaded To PARAM_ENV[script.nonargs.paramlist]: '${PARAM_ENV["script.nonargs.paramlist"]}'"
# <<< Parse Parameters. <<<


# >>> Setup Default Config Env For The Process >>>
# Only These Config Overrides Will Get Picked From The Env
# So If Default Is Not Available But We Still Want To Pick 
# From Env Then A Null Must Be Specified e.g. CONFIG_DEFAULTS_ENV["script.conf.unknown"]="NULL"
##############################################################################
    CONFIG_DEFAULTS_ENV["script.read.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"
    
    CONFIG_DEFAULTS_ENV["script.write.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"
# <<< Setup Default Config Env For The Process. <<<


# >>> Functions For Setting, Merging & Resolving Configs & Dynamic Templates >>>
##############################################################################
    add2ConfigEnv() {
        local keyname="${1}"
        local value="${2}"
        local caller_script="$(caller | cut -d' ' -f2-)"

        if [[ ${CONFIG_DEFAULTS_ENV[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_ADD_ENV[${keyname}]+_} ]]
            then
                CONFIG_ENV_LINEAGE[${keyname}]="${CONFIG_ENV_LINEAGE[${keyname}]} => '${caller_script}'@add2ConfigEnv '${keyname}' '${value}'"
            else
                CONFIG_ENV_LINEAGE[${keyname}]="'CONFIG_DEFAULTS_ENV[${keyname}]':'${CONFIG_DEFAULTS_ENV[${keyname}]}' => '${caller_script}'@add2ConfigEnv '${keyname}' '${value}'"
            fi

            CONFIG_ADD_ENV[${keyname}]="${value}"
        else
            echo "WARNING: SKIPPING CONFIG ADDITION TO ENV FOR CONFIG: '${keyname}' AS ONLY CONFIGS FOR WHICH DEFAULTS ARE SET CAN BE USED WITHIN THE PROCESS" 1>&2
        fi
    }

    refreshConfigEnv() {
        local caller_script="$(caller | cut -d' ' -f2-)"
        echo "INFO: Config Refresh Initiated From: '${caller_script}'" 1>&2
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

   evalConfig() {
        refreshConfigEnv
        local keyname="${1}"
        local caller_script="$(caller | cut -d' ' -f2-)"

        if [[ ${CONFIG_ENV[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_EVAL_LINEAGE[${keyname}]+_} ]]
            then
                CONFIG_EVAL_LINEAGE[${keyname}]="${CONFIG_EVAL_LINEAGE[${keyname}]} #Begin Eval >>> 'CONFIG_ENV[${keyname}]':'${CONFIG_ENV[${keyname}]}' => '${caller_script}'@evalConfig '${keyname}'"
            else
                CONFIG_EVAL_LINEAGE[${keyname}]="#Begin Eval >>> 'CONFIG_ENV[${keyname}]':'${CONFIG_ENV[${keyname}]}' => '${caller_script}'@evalConfig '${keyname}'"
            fi

            local curr_value="${CONFIG_ENV[${keyname}]}"
            local next_value=""

            while [[ "${curr_value}" =~ .*\$\{[^{\}]*}.* ]]
            do
                next_value="$(eval echo "${curr_value}")"
                CONFIG_EVAL_LINEAGE[${keyname}]="${CONFIG_EVAL_LINEAGE[${keyname}]} -> ${next_value}"
                if [[ "${next_value}" == "${curr_value}" ]]
                then
                    break
                else
                    curr_value="${next_value}"
                fi
            done

            CONFIG_EVAL_LINEAGE[${keyname}]="${CONFIG_EVAL_LINEAGE[${keyname}]} #End Eval <<<"
            CONFIG_EVAL_ENV[${keyname}]="${curr_value}"
        else
            help "ERROR: Invalid Config Reference: CONFIG_ENV[${keyname}]"
        fi
    }

    # To Be Defined After Log File Definition
    showConfigs() {
        for arg in "$@"
        do
            local container_name="${arg}"
            echo -e "\n# Begin Show Configs: ${container_name} >>>"
            for k in $(eval echo "\${!${container_name}[@]}")
            do
                echo -e "\t INFO: ${container_name}[${k}]='$(eval echo "\${${container_name}[${k}]}")'"
            done
            echo -e "# End Show Configs: ${container_name} <<<\n"
        done
    }
    # showConfigs PARAM_ENV RUN_ENV VAR_ENV CONFIG_ENV CONFIG_EVAL_ENV CONFIG_ENV_LINEAGE CONFIG_EVAL_LINEAGE
# <<< Functions For Setting, Merging & Resolving Configs & Dynamic Templates. <<<


x=10
add2ConfigEnv "script.write.rootdir" '"${x}"'
evalConfig "script.write.rootdir"
evalConfig "script.write.rootdir"
echo ${CONFIG_EVAL_ENV["script.write.rootdir"]}

#echo ${RUN_ENV[script.run2.hostname]}

showConfigs PARAM_ENV RUN_ENV VAR_ENV CONFIG_ENV CONFIG_EVAL_ENV CONFIG_ENV_LINEAGE CONFIG_EVAL_LINEAGE
