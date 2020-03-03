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


# Set magic variables for current file, directory, os, etc.
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
# shellcheck disable=SC2034,SC2015
__invocation="$(printf %q "${__file}")$( (($#)) && printf ' %q' "$@" || true)"
__paramlist="${@}"

# Print Info
echo "Script Dir: ${__dir}"
echo "Script Complete Path: ${__file}"
echo "Script File Base Name: ${__base}"
echo "Script Invocation: ${__invocation}"
echo "Script Param List: ${__paramlist}"


# >>> Define Usage And Helptext >>>
##############################################################################
__sample_usage="SAMPLE USAGE: ${0} [ -f fallback_script ] [ -r region_name ] [ -e runtime_env ] ..."

[[ "${__usage+_}" ]] || read -r -d '' __usage <<-'EOF'|| true # exits non-zero when EOF encountered
-f    fallback_script     <<Optional Parameter>>: If this parameter is specified then the script will
                            handover control to this fallback_script(passing all parameters as is) 
                            and exit after the fallback_script completes. This option can be useful 
                            for executing alternative scripts in case current script is failing.             

  -r    region_name         <<Optional Parameter, Default Val: APAC>>: Region name in which script will be run. 

  -e    runtime_env         <<Optional Parameter, Default Val: PROD>>: Current Run Env Name e.g. dev/uat/prod.
                            Default value of runtime_env is APAC

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
                region_name="${OPTARG}"
                ;;
            e)
                runtime_env="${OPTARG}"
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


echo "INFO: region_name Is Set To: '${region_name}'"
echo "INFO: runtime_env Is Set To: '${runtime_env}'"

# >>> Signal trapping and backtracing >>>
##############################################################################
    function __cleanup_before_exit () {
        local final_return_status="${?}"

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
# <<< Signal trapping and backtracing <<<

echo -e "\n#  >>> BEGIN SCRIPT: '${__invocation}' >>>\n"


if [[ ${fallback_script+_} ]]
then
    echo "WARNING: Skipping Run Of Current Script: ${__file}"
    echo "WARNING: triggering the fallback_script: ${fallback_script}"
    source "${fallback_script}"
    echo "INFO: fallback_script Completed Successfully."
    exit 0
fi

