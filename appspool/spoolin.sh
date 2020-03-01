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
    __env_dict_list="PARAM_ENV RUN_ENV CONFIG_DEFAULTS_ENV CONFIG_ADD_ENV CONFIG_ENV_LINEAGE CONFIG_ENV CONFIG_EVAL_ENV CONFIG_EVAL_LINEAGE VAR_ENV"

    for dict in ${__env_dict_list}
    do
        unset ${dict}
    done

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


# >>> Set VAR_ENV variables defaults used within the script  >>>
##############################################################################
    VAR_ENV["script.current.print.indent"]=""
# <<< Set variables defaults used within the script. <<<


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
        if [[ ${RUN_ENV["script.app.log.file"]+_} ]]
        then
            echo -e "${VAR_ENV["script.current.print.indent"]}$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}"
            if [[ "${PARAM_ENV["script.verbose.mode"]}" == "ON" ]]
            then
                echo -e "${VAR_ENV["script.current.print.indent"]}$(date -u +"%Y-%m-%d %H:%M:%S UTC") $(printf "[%9s]" "${log_level}") ${log_line}" >> "${RUN_ENV["script.app.log.file"]}"
            else
                echo -e "${VAR_ENV["script.current.print.indent"]}$(date -u +"%Y-%m-%d %H:%M:%S UTC") $(printf "[%9s]" "${log_level}") ${log_line}" 1>&2
            fi
        else
            echo -e "${VAR_ENV["script.current.print.indent"]}$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}"
        fi
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
                                               Pass Root Configrations For The Script Run.

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

                info "PARAM_ENV[script.process.name] Is Set To: '${PARAM_ENV["script.process.name"]}'"
                ;;
            a)
                PARAM_ENV["script.process.appname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.process.appname"]}" != "${PARAM_ENV["script.process.appname"],,}" ]] && { help "ERROR: PARAM_ENV[script.process.appname] Value Must Be In Lower Case"; }
                
                info "PARAM_ENV[script.process.appname] Is Set To: '${PARAM_ENV["script.process.appname"]}'"
                ;;
            e)
                PARAM_ENV["script.runtime.envname"]="${OPTARG}"

                [[ "${PARAM_ENV["script.runtime.envname"]}" != "${PARAM_ENV["script.runtime.envname"],,}" ]] && { help "ERROR: PARAM_ENV[script.runtime.envname] Value Must Be In Lower Case"; }

                info "PARAM_ENV[script.runtime.envname] Is Set To: '${PARAM_ENV["script.runtime.envname"]}'"
                ;;
            c)  
                PARAM_ENV["script.config.rootfile"]="${OPTARG}"

                [[ "$(dirname ${PARAM_ENV["script.config.rootfile"]})" == "." ]] && PARAM_ENV["script.config.rootfile"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.config.rootfile"]}"

                [[ -f "${PARAM_ENV["script.config.rootfile"]}" ]] || { help "ERROR: PARAM_ENV[script.config.rootfile]:'${PARAM_ENV["script.config.rootfile"]}' Not Found"; }
                
                info "PARAM_ENV[script.config.rootfile] Is Set To: '${PARAM_ENV["script.config.rootfile"]}'"
                ;;
            d)
                PARAM_ENV["script.debug.mode"]="ON"
                info "PARAM_ENV[script.debug.mode] Is Set To: '${PARAM_ENV["script.debug.mode"]}'"
                ;;
            v)  
                PARAM_ENV["script.verbose.mode"]="ON"
                
                info "PARAM_ENV[script.verbose.mode] Is Set To: '${PARAM_ENV["script.verbose.mode"]}'"
                
                warning "SETTING PARAM_ENV[script.verbose.mode] TO: '${PARAM_ENV["script.verbose.mode"]}' IS NOT RECOMMENDED FOR PRODUCTION RUNS. TURN VERBOSE MODE TO OFF IF NOT DOING TEST RUNS"

                warning "PROCESS WILL HALT FOR 15 SECONDS BEFORE EXECUTION IN VERBOSE MODE RUNS"
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

    if [[ ${PARAM_ENV["script.config.rootfile"]+_} ]]
    then
        if [[ -f "${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.appname"]}.rootconfig.conf.sh" ]]
        then
            PARAM_ENV["script.config.rootfile"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.appname"]}.rootconfig.conf.sh"
            alert "PARAM_ENV[script.config.rootfile] IS SET TO (USING DEFAULT): '${PARAM_ENV["script.config.rootfile"]}'"
        fi
    fi

    PARAM_ENV["script.nonargs.paramlist"]="${@}"
    info "All Remaining Params Are Loaded To PARAM_ENV[script.nonargs.paramlist]: '${PARAM_ENV["script.nonargs.paramlist"]}'"
# <<< Parse Parameters. <<<


# >>> Functions For Pretty Printing, Setting, Merging & Resolving Configs & Dynamic Templates >>>
##############################################################################
    getFuncCallTrace() {
        local container_name="FUNCNAME"
        local function_trace=""
        
        for k in $(eval echo "\${!${container_name}[@]}")
        do
            [[ "${k}" == "0" ]] && continue
            if [[ "${function_trace}" == "" ]]
            then
                function_trace="$(eval echo "\${${container_name}[${k}]}")"
            else
                function_trace="$(eval echo "\${${container_name}[${k}]}").${function_trace}"
            fi
        done
        
        echo "${function_trace}"
    }
    
    addIndent() {
        VAR_ENV["script.current.print.indent"]="    |${VAR_ENV["script.current.print.indent"]}"
    }
    
    subtractIndent () {
        VAR_ENV["script.current.print.indent"]="$( echo "${VAR_ENV["script.current.print.indent"]}" | sed 's/^    |//1' )"
    }
    
    beginFuncInfo() {
        addIndent
        
        info "\n# >>> Begin Function - ${1} >>>"
        info "##############################################################################"
        
        addIndent
    }
    
    endFuncInfo() {
        subtractIndent
        info "##############################################################################"
        info "${VAR_ENV["script.current.print.indent"]}# <<< End Function - ${1}. <<<"
        
        subtractIndent  
    }
    
    add2ConfigEnv() {
        local caller_script="$(caller | cut -d' ' -f2-)"
        local function_trace="$(getFuncCallTrace)"
        local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
        beginFuncInfo "${function_signature}"

        local keyname="${1}"
        local value="${2}"

        if [[ ${CONFIG_DEFAULTS_ENV[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_ADD_ENV[${keyname}]+_} ]]
            then
                CONFIG_ENV_LINEAGE[${keyname}]="${CONFIG_ENV_LINEAGE[${keyname}]} => ${function_signature}"
            else
                CONFIG_ENV_LINEAGE[${keyname}]="'CONFIG_DEFAULTS_ENV[${keyname}]:${CONFIG_DEFAULTS_ENV[${keyname}]}' => ${function_signature}"
            fi

            CONFIG_ADD_ENV[${keyname}]="${value}"
        else
            warning "SKIPPING CONFIG ADDITION TO ENV FOR CONFIG: '${keyname}' AS ONLY CONFIGS FOR WHICH DEFAULTS ARE SET CAN BE USED WITHIN THE PROCESS"
        fi

        endFuncInfo "${function_signature}"
    }

    refreshConfigEnv() {
        local caller_script="$(caller | cut -d' ' -f2-)"
        local function_trace="$(getFuncCallTrace)"
        local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
        beginFuncInfo "${function_signature}"

        for k in "${!CONFIG_DEFAULTS_ENV[@]}"
        do
            if [[ ${CONFIG_ADD_ENV[${k}]+_} ]]
            then
                CONFIG_ENV[${k}]="${CONFIG_ADD_ENV[${k}]}"
            else
                CONFIG_ENV[${k}]="${CONFIG_DEFAULTS_ENV[${k}]}"
            fi
        done
        
        endFuncInfo "${function_signature}"
    }

   evalConfig() {       
        local caller_script="$(caller | cut -d' ' -f2-)"
        local function_trace="$(getFuncCallTrace)"
        local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
        beginFuncInfo "${function_signature}"

        local keyname="${1}"

        refreshConfigEnv
        if [[ ${CONFIG_ENV[${keyname}]+_} ]]
        then
            if [[ ${CONFIG_EVAL_LINEAGE[${keyname}]+_} ]]
            then
                CONFIG_EVAL_LINEAGE[${keyname}]="${CONFIG_EVAL_LINEAGE[${keyname}]} #Begin Eval >>> 'CONFIG_ENV[${keyname}]:${CONFIG_ENV[${keyname}]}' => ${function_signature}"
            else
                CONFIG_EVAL_LINEAGE[${keyname}]="#Begin Eval >>> 'CONFIG_ENV[${keyname}]:${CONFIG_ENV[${keyname}]}' => ${function_signature}"
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

            CONFIG_EVAL_LINEAGE[${keyname}]="${CONFIG_EVAL_LINEAGE[${keyname}]} #End Eval <<<."
            CONFIG_EVAL_ENV[${keyname}]="${curr_value}"
        else
            emergency "Invalid Config Reference: CONFIG_ENV[${keyname}]"
        fi

        endFuncInfo "${function_signature}"
    }

    # To Be Defined After Log File Definition
    showConfigs() {
        local caller_script="$(caller | cut -d' ' -f2-)"
        local function_trace="$(getFuncCallTrace)"
        local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
        beginFuncInfo "${function_signature}"

        local num_of_params="${#}"
        local print_config_list=""

        if [[ "${num_of_params}" == "0" ]]
        then
            print_config_list="${__env_dict_list}"
        else
            print_config_list="$@"
        fi
        for arg in ${print_config_list}
        do
            local container_name="${arg}"
            info "\n# >>> Begin Show Configs: ${container_name} >>>"
            addIndent
            for k in $(eval echo "\${!${container_name}[@]}")
            do
                info "${container_name}[${k}]='$(eval echo "\${${container_name}[${k}]}")'"
            done
            subtractIndent
            info "# <<< End Show Configs: ${container_name}. <<<\n"
        done

        endFuncInfo "${function_signature}"
    }
# <<< Functions For Pretty Printing, Setting, Merging & Resolving Configs & Dynamic Templates. <<<


# >>> Signal trapping and backtracing >>>
##############################################################################
    function __cleanup_before_exit () {
        local final_return_status="${?}"
        
        local caller_script="$(caller | cut -d' ' -f2-)"
        local function_trace="$(getFuncCallTrace)"
        local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
        beginFuncInfo "${function_signature}"


        if [[ ${RUN_ENV["script.app.tmp.dir"]+_} ]]
        then
            alert "DELETING THE TEMP DIR USING THE COMMAND: 'rm -fr ${RUN_ENV["script.app.tmp.dir"]}'"
            rm -fr "${RUN_ENV["script.app.tmp.dir"]}"
        fi
        # Add logic for deletion of any leftover temp files
        # Add logic for deletion of log older than retention period
        info "Cleaning up. Done"

        info "Printing The Complete Config Env Used During This Run Before Exit:"
        showConfigs
        
        endFuncInfo "${function_signature}"

        subtractIndent
        if [[ "${final_return_status}" == "0" ]]
        then
            info "#  <<< END SCRIPT <<SUCCESS>>: '${RUN_ENV["script.run.invocation"]}'. <<<"
        else
            alert "#  <<< END SCRIPT <<FAILURE>>: '${RUN_ENV["script.run.invocation"]}'. <<<"
        fi
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


# >>> Setup Default Config Env For The Process >>>
# Only These Config Overrides Will Get Picked From The Env
# So If Default Is Not Available But We Still Want To Pick 
# From Env Then A Null Must Be Specified e.g. CONFIG_DEFAULTS_ENV["script.conf.unknown"]="NULL"
##############################################################################
    CONFIG_DEFAULTS_ENV["script.read.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"
    
    CONFIG_DEFAULTS_ENV["script.write.rootdir"]="${RUN_ENV["script.dir.path"]%%/}/${PARAM_ENV["script.process.name"]}"

    
# <<< Setup Default Config Env For The Process. <<<


# >>> Source Root Config File >>>
##############################################################################
    if [[ "${PARAM_ENV["script.config.rootfile"]+_}" ]]
    then
        info "Sourcing Param Env Root Config File: '${PARAM_ENV["script.config.rootfile"]}'"
        source "${PARAM_ENV["script.config.rootfile"]}"

        refreshConfigEnv
    fi
# <<< Source Root Config File. <<<

# >>> Prepare runtime env using parameters >>>
##############################################################################
    # Set Current Batch Id, Generate New Id If The Batch File Is Not Already Present
    RUN_ENV["script.app.batchid.dir"]="${CONFIG_ENV["script.write.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-batch-info/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.run.whoami"]}"

    [[ -d  "${RUN_ENV["script.app.batchid.dir"]}" ]] || mkdir -p "${RUN_ENV["script.app.batchid.dir"]}"
    RUN_ENV["script.app.batchid.file"]="${RUN_ENV["script.app.batchid.dir"]%%/}/current-batchid.env"

    RUN_ENV["script.app.batchid.set.flag"]="TRUE"
    if [[ -s "${RUN_ENV["script.app.batchid.file"]}" ]]
    then
        RUN_ENV["script.app.batchid.val"]="$( cat "${RUN_ENV["script.app.batchid.file"]}" | sed -e '/^\s*$/d' -e '/\s*#.*$/d' | tail -1 )"
        if [[ "${RUN_ENV["script.app.batchid.val"]:-}" == "" ]]
        then
            RUN_ENV["script.app.batchid.val"]="${RUN_ENV["script.run.date.yyyymmdd"]}"
            echo "${RUN_ENV["script.app.batchid.val"]}" > "${RUN_ENV["script.app.batchid.file"]}"
        else
            RUN_ENV["script.app.batchid.set.flag"]="FALSE"
            RUN_ENV["script.app.batchid.val"]="${RUN_ENV["script.app.batchid.val"]}"
        fi
    else
        RUN_ENV["script.app.batchid.val"]="${RUN_ENV["script.run.date.yyyymmdd"]}"
        echo "${RUN_ENV["script.app.batchid.val"]}" > "${RUN_ENV["script.app.batchid.file"]}"
    fi

    RUN_ENV["script.app.log.dir"]="${CONFIG_ENV["script.write.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-log/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.run.whoami"]}/${RUN_ENV["script.file.base"]}/${RUN_ENV["script.app.batchid.val"]}"

    RUN_ENV["script.app.log.current.dir"]="${CONFIG_ENV["script.write.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-log/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.run.whoami"]}/${RUN_ENV["script.file.base"]}/current"

    [[ -d  "${RUN_ENV["script.app.log.dir"]}" ]] || mkdir -p "${RUN_ENV["script.app.log.dir"]}"
    [[ -d  "${RUN_ENV["script.app.log.current.dir"]}" ]] || mkdir -p "${RUN_ENV["script.app.log.current.dir"]}"

    RUN_ENV["script.app.log.file"]="${RUN_ENV["script.app.log.dir"]%%/}/${RUN_ENV["script.run.unique.runid"]}.log"
    RUN_ENV["script.app.log.current.pointer.file"]="${RUN_ENV["script.app.log.current.dir"]%%/}/current.log"
    RUN_ENV["script.app.log.previous.pointer.file"]="${RUN_ENV["script.app.log.current.dir"]%%/}/previous.log"
    touch "${RUN_ENV["script.app.log.file"]}"

    if [[ -f "${RUN_ENV["script.app.log.current.pointer.file"]}" ]]
    then
        ln -nvfs "$( readlink "${RUN_ENV["script.app.log.current.pointer.file"]}" )" "${RUN_ENV["script.app.log.previous.pointer.file"]}"
    fi
    ln -nvfs "${RUN_ENV["script.app.log.file"]}" "${RUN_ENV["script.app.log.current.pointer.file"]}"

    RUN_ENV["script.app.tmp.dir"]="${CONFIG_ENV["script.write.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-tmp/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.run.whoami"]}/${RUN_ENV["script.file.base"]}/${RUN_ENV["script.run.unique.runid"]}.tmp.dir"
    
    [[ -d  "${RUN_ENV["script.app.tmp.dir"]}" ]] || mkdir -p "${RUN_ENV["script.app.tmp.dir"]}"

    RUN_ENV["app.common.config.dir"]="${CONFIG_ENV["script.read.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-conf/common/${PARAM_ENV["script.runtime.envname"]}"

    RUN_ENV["app.config.dir"]="${CONFIG_ENV["script.read.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-conf/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}"

    RUN_ENV["app.script.config.dir"]="${CONFIG_ENV["script.read.rootdir"]%%/}/${PARAM_ENV["script.process.name"]}/app-conf/${PARAM_ENV["script.process.appname"]}/${PARAM_ENV["script.runtime.envname"]}/${RUN_ENV["script.file.base"]}"
    
    [[ -d  "${RUN_ENV["app.common.config.dir"]}" ]] || mkdir -p "${RUN_ENV["app.common.config.dir"]}"
    [[ -d  "${RUN_ENV["app.config.dir"]}" ]] || mkdir -p "${RUN_ENV["app.config.dir"]}"
    [[ -d  "${RUN_ENV["app.script.config.dir"]}" ]] || mkdir -p "${RUN_ENV["app.script.config.dir"]}"

    notice "Log File: ${RUN_ENV["script.app.log.file"]}"
    notice "Log Current Run Softlink Pointer File: ${RUN_ENV["script.app.log.current.pointer.file"]}"
    [[ -f "${RUN_ENV["script.app.log.previous.pointer.file"]}" ]] && notice "Log Previous Run Softlink Pointer File: ${RUN_ENV["script.app.log.previous.pointer.file"]}"

    if [[ "${PARAM_ENV["script.verbose.mode"]}" == "ON" ]]
    then
        alert "STARTING PROCESS IN VERBOSE MODE"
    else
        exec 2>> "${RUN_ENV["script.app.log.file"]}"
    fi
# <<< Prepare runtime env using parameters <<<


# >>> Print env info and source configs >>>
##############################################################################
    info "#  >>> BEGIN SCRIPT: '${RUN_ENV["script.run.invocation"]}' >>>"
    addIndent
    showConfigs

    [[ "${RUN_ENV["script.app.batchid.set.flag"]}" == "TRUE"  ]] && alert "SETTING RUN_ENV["script.app.batchid.val"]: ${RUN_ENV["script.app.batchid.val"]}"
    export RUN_ENV["script.app.batchid.val"]="${RUN_ENV["script.app.batchid.val"]}"

    # source common env 
    for file in $(find "${RUN_ENV["app.common.config.dir"]}" -maxdepth 1 -name '*.sh'); 
    do
        notice "Sourcing file: '${file}' from RUN_ENV["app.common.config.dir"]: '${RUN_ENV["app.common.config.dir"]}'"
        source "${file}"; 
    done

    # source app specific envs
    for file in $(find "${RUN_ENV["app.config.dir"]}" -maxdepth 1 -name '*.sh'); 
    do
        notice "Sourcing file: '${file}' from RUN_ENV["app.config.dir"]: '${RUN_ENV["app.config.dir"]}'"
        source "${file}"; 
    done

    # source script specific env
    for file in $(find "${RUN_ENV["app.script.config.dir"]}" -maxdepth 1 -name '*.sh'); 
    do
        notice "Sourcing file: '${file}' from RUN_ENV["app.script.config.dir"]: '${RUN_ENV["app.script.config.dir"]}'"
        source "${file}"; 
    done
# <<< Print env info and source configs <<<


# >>> Functions >>>
##############################################################################

# <<< Functions <<<

# >>> main >>>
##############################################################################

# <<< main <<<