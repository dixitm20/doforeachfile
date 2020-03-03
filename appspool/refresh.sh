#!/usr/bin/env bash

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


# Set magic variables for current file, directory, os, etc.
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
__invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"
__paramlist="${@}"
__indent=""


# Print Info
echo "Script Dir: ${__dir}"
echo "Script Complete Path: ${__file}"
echo "Script File Base Name: ${__base}"
echo "Script Invocation: ${__invocation}"
echo "Script Param List: ${__paramlist}"

# >>> Pretty Print Fucntions >>>
##############################################################################
log() {
    echo -e "${__indent}$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${@}"
}

addIndent() {
    __indent="    ${__indent}"
}

subtractIndent () {
    __indent="$( echo "${__indent}" | sed 's/^    //1' )"
}
# <<< Pretty Print Fucntions. <<<


# >>> Define Usage And Helptext >>>
##############################################################################
__sample_usage="SAMPLE USAGE: ${0} [ -f fallback_script ] [ -r region_name ] [ -e runtime_env ] table_name mis_dt..."

[[ "${__usage+_}" ]] || read -r -d '' __usage <<-'EOF'|| true # exits non-zero when EOF encountered
-f    fallback_script     <<Optional Parameter>>: If this parameter is specified then the script will
                            handover control to this fallback_script(passing all parameters as is) 
                            and exit after the fallback_script completes. This option can be useful 
                            for executing alternative scripts in case current script is failing.             

  -r    region_name         <<Optional Parameter, Default Val: APAC>>: Region name in which script will be run.
                            Allowed values are APAC/EMEA. 

  -e    runtime_env         <<Optional Parameter, Default Val: PROD>>: Current Run Env Name.
                            Allowed values are DEV/ST/UAT/PAT/SNDBX/PROD

  -h    --help              This Page
EOF

    # shellcheck disable=SC2015
    [[ "${__helptext+_}" ]] || read -r -d '' __helptext <<-'EOF' || true # exits non-zero when EOF encountered
    Generic Script For Refreshing Arcadia Views.
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


# >>> Parse Opt Args >>>
##############################################################################
# unset variables
unset -v fallback_script
unset -v region_name
unset -v runtime_env

# Set Defaults
region_name="APAC"
runtime_env="PROD"

# Read Options
while getopts ":f:r:e:" o; do
    case "${o}" in
        f)
            fallback_script="${OPTARG}"

            [[ "$(dirname ${fallback_script})" == "." ]] && fallback_script="${__dir%%/}/${fallback_script}"
            [[ -f "${fallback_script}" ]] || { help "ERROR: fallback_script:'${fallback_script}' Not Found"; }
            
            echo "INFO: fallback_script Is Set To: '${fallback_script}'"              
            ;;
        r)
            region_name="${OPTARG^^}"
            ;;
        e)
            runtime_env="${OPTARG^^}"
            ;;
        h)  
            help "Help Using ${0}"
            ;;
        :)  
            echo "ERROR: Option -$OPTARG Requires An Argument"
            ;;
        \?)
            help "ERROR: Invalid Option -$OPTARG"
            ;;
    esac
done

shift $((OPTIND-1))

echo -e "\nINFO: region_name Is Set To: '${region_name}'"
echo "INFO: runtime_env Is Set To: '${runtime_env}'"
# <<< Parse Opt Args. <<<


# >>> Parse Nonopt Args, Set Defaults For Variables & Define Functions >>>
##############################################################################
if [[ ${#} -lt 2 ]]
then
    help "ERROR: Missing Required Arguments: table_name && mis_dt"
fi

table_name="${1}"
echo "INFO: table_name Is Set To: '${table_name}'"
mis_dt="${2}"
echo "INFO: mis_dt Is Set To: '${mis_dt}'"

user="$(whoami)"
echo "INFO: User Is Set To: '${user}'"
host="$(hostname)"
echo "INFO: Hostname Is Set To: '${host}'"


hive_src_schema_name="${user}_staging"
hive_tgt_schema_name="${user}_staging"

tgt_column_list=""
view_refresh_query=""

# All Codes Must Be In Caps
apac_country_list=( "HDD" )
emea_country_list=( "Monitor" )

# All Codes Must Be In Caps
declare -A country_code_2_id_map=( ["HDD"]="Samsung" ["Monitor"]="Dell" ["Keyboard"]="A4Tech" )


__env_dict_list="inscope_country_code_id_list inscope_country_code_table_list inscope_max_mis_dt_foreach_country_code inscope_country_id_2_code_map"

for dict in ${__env_dict_list}
do
    unset ${dict}
done

declare -A inscope_country_code_id_list
declare -A inscope_country_code_table_list
declare -A inscope_max_mis_dt_foreach_country_code
declare -A inscope_country_id_2_code_map
# <<< Parse Nonopt Args, Set Defaults For Variables & Define Functions. <<<


# >>> Signal Trapping And Backtracing >>>
##############################################################################
    function __cleanup_before_exit () {
        local final_return_status="${?}"

        subtractIndent
        if [[ "${final_return_status}" == "0" ]]
        then
            echo -e "\n#  <<< END SCRIPT <<SUCCESS>>: '${__invocation}'. <<<"
        else
            echo -e "\n#  <<< END SCRIPT <<FAILURE>>: '${__invocation}'. <<<"
        fi
    }

    trap __cleanup_before_exit EXIT

    # requires `set -o errtrace`
    __err_report() {
        local error_code=${?}
        echo "Error in ${__file} in function ${1} on line ${2}"
        exit ${error_code}
    }
    # Uncomment the following line for always providing an error backtrace
    trap '__err_report "${FUNCNAME:-.}" ${LINENO}' ERR
# <<< Signal Trapping And Backtracing. <<<


echo -e "\n#  >>> BEGIN SCRIPT: '${__invocation}' >>>\n"
addIndent


# >>> Handover To fallback_script If -f Option Is Used >>>
##############################################################################
    if [[ ${fallback_script+_} ]]
    then
        log "WARNING: Skipping Run Of Current Script: '${__invocation}'"
        log "WARNING: triggering the fallback_script: '${fallback_script} ${__paramlist}'"
        source "${fallback_script}" ${__paramlist}
        log "INFO: fallback_script Completed Successfully."
        exit 0
    fi
# <<< Handover To fallback_script If -f Option Is Used. <<<


# >>> Env Specific Logic >>>
##############################################################################
    case ${runtime_env} in
        "PROD")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_staging"
        ;;

        "SNDBX")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_work"
        ;;
        "PAT")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_work"
        ;;
        "UAT")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_work"
        ;;
        "ST")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_work"
        ;;
        "DEV")
            log "INFO: Loading Configrations For Env: '${runtime_env}'"
            hive_schema_name="${user}_work"
        ;;
        *)
            help "ERROR: Env: '${runtime_env}' Is Not A Valid Env."
            exit 1
        ;;
    esac

    log "INFO: hive_schema_name Is Set To: ${hive_schema_name}"
# <<< Env Specific Logic <<<


# >>> Region Specific Logic >>>
##############################################################################
    case ${region_name} in
        "APAC")
            log "INFO: Loading Configrations For Region: '${region_name}'"
        ;;

        "EMEA")
            log "INFO: Loading Configrations For Region: '${region_name}'"
        ;;
        *)
            help "ERROR: Region: '${region_name}' Is Not A Valid Region"
        ;;
    esac
# <<< Region Specific Logic. <<<


# >>> Functions >>>
##############################################################################
populateInScopeCountryInfo() {
    local container_name="apac_country_list"
    [[ "${region_name}" == "EMEA" ]] && container_name="emea_country_list"
    
    for idx in $(eval echo "\${!${container_name}[@]}")
    do
        local country_code="$(eval echo "\${${container_name}[${idx}]}")"
        if [[ ${country_code_2_id_map[${country_code}]+_} ]]
        then
            local country_codeid="${country_code_2_id_map[${country_code}]}"

            inscope_country_code_id_list[${country_code}]="${country_codeid}"
            inscope_country_code_table_list[${country_code}]="${hive_src_schema_name^^}.${table_name^^}_${country_code^^}"
            inscope_max_mis_dt_foreach_country_code[${country_code}]="${mis_dt}"
            inscope_country_id_2_code_map[${country_codeid}]="${country_code}"
        else
            log "ERROR: Country CodeId Missing In 'country_code_2_id_map' For Country Code: '${country_code}'"
            exit 1
        fi
    done
}

showConfigs() {
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
            echo -e "\n${__indent}# >>> Begin Show Configs: ${container_name} >>>"
            addIndent
            for k in $(eval echo "\${!${container_name}[@]}")
            do
                echo "${__indent}${container_name}[${k}]='$(eval echo "\${${container_name}[${k}]}")'"
            done
            subtractIndent
            echo -e "${__indent}# <<< End Show Configs: ${container_name}. <<<\n"
        done
    }

insertQueryBuilder() {
    local column_list="${tgt_column_list}"

    local container_name="apac_country_list"
    [[ "${region_name}" == "EMEA" ]] && container_name="emea_country_list"
    
    local insert_clause="INSERT INTO ${hive_tgt_schema_name}.${table_name}"
    local select_clause=""
    for idx in $(eval echo "\${!${container_name}[@]}")
    do
        local country_code="$(eval echo "\${${container_name}[${idx}]}")"
        if [[ "${select_clause}" == "" ]]
        then
            select_clause="SELECT ${column_list} FROM ${inscope_country_code_table_list[${country_code}]} WHERE MIS_DT > ${inscope_max_mis_dt_foreach_country_code[${country_code}]}"
        else
            select_clause="${select_clause} UNION ALL SELECT ${column_list} FROM ${inscope_country_code_table_list[${country_code}]} WHERE MIS_DT > ${inscope_max_mis_dt_foreach_country_code[${country_code}]}"
        fi
    done
    
    view_refresh_query="${insert_clause} ${select_clause}"
    log "INFO: Using Following Query To Refresh The Arcadia View: '${view_refresh_query}'"
}

refreshMaxMisDtFromTgt() {
    inscope_max_mis_dt_foreach_country_code=""
}

getTargetColListFromTgt() {
    tgt_column_list=""
}
# <<< Functions. <<<


# >>> Main >>>
##############################################################################
# Populate & Print Inscope Region Details Into Env
populateInScopeCountryInfo
log "INFO: Printing Defaults Config Loaded For Given Region: '${region_name}' As Below:"
addIndent
showConfigs
subtractIndent

# Function For Refreshing Max MIS_DT Information In 'inscope_max_mis_dt_foreach_country_code' After Pulling From Target Table
refreshMaxMisDtFromTgt

log "INFO: Printing Refreshed Max MIS_DT Per Country Code Information After Pulling From Target Table: '${hive_tgt_schema_name}.${table_name}' As Below:"
addIndent
showConfigs "inscope_max_mis_dt_foreach_country_code"
subtractIndent

# Function For Getting The Dynamic Column List From Target And Loading Into 'tgt_column_list' Variable
getTargetColListFromTgt

# Function To Generate The Insert SQL Into: 'view_refresh_query' Variable For Refreshing The View
insertQueryBuilder

# <<< Main. <<<