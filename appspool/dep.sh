 
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

###############################################################################
# Environment
###############################################################################

# $_ME
#
# Set to the program's basename.
_ME=$(basename "${0}")

###############################################################################
# Help
###############################################################################

# _print_help()
#
# Usage:
#   _print_help
#
# Print the program help information.
_print_help() {
  cat <<HEREDOC
      _                 _
  ___(_)_ __ ___  _ __ | | ___
 / __| | '_ \` _ \\| '_ \\| |/ _ \\
 \\__ \\ | | | | | | |_) | |  __/
 |___/_|_| |_| |_| .__/|_|\\___|
                 |_|
Boilerplate for creating a simple bash script with some basic strictness
checks and help features.
Usage:
  ${_ME} [<arguments>]
  ${_ME} -h | --help
Options:
  -h --help  Show this screen.
HEREDOC
}

###############################################################################
# Program Functions
###############################################################################

__parse_json() {
    python <<EOF
import json
parsed = json.loads('''${@}''')

for k in parsed:
	print("{} {}".format(k,parsed[k]))
EOF
}

__get_param_type() {
    local paramval="${1}"
    local trimmed_paramval="$( echo "${paramval}" | sed 's/^\s*//1' | sed 's/\s*$//1' )"
    echo "Fetching the type of paramval: '${paramval}'."
    
    if [[ "${trimmed_paramval::1}" == "{" && "${trimmed_paramval:(-1)}" == "}" ]]
    then
        echo "json"
    else
        echo "plain/unknown"
    fi
}

__load_global_params() {
    local paramsno="${1}"
    local paramval="${2}"
    local paramname="arg_${paramsno}"
    local paramtype="$( __get_param_type "${paramval}" )"

    case "${paramtype}" in
        "json")
            echo "Type of paramval: '${paramval}' is json. Applying json parser for loading params to __global_param."
            while IFS=' ' read -r k v
            do
                echo "$k=$v"
            done <<< "$(__parse_json ${json_data})" 
            ;;
        *)
            echo "Type of paramval: '${paramval}' is plain/unknown. Storing parameter value as is to __global_param[arg_${paramsno}]"
            ;;
    esac
}


###############################################################################
# Main
###############################################################################

# _main()
#
# Usage:
#   _main [<options>] [<arguments>]
#
# Description:
#   Entry point for the program, handling basic option parsing and dispatching.
_main() {
  # Avoid complex option parsing when only one program option is expected.
  if [[ "${1:-}" =~ ^-h|--help$  ]]
  then
    _print_help
  else
    #for t in "$(parse_data '{"a":10,"b":20}')"; do echo "$t"; done
    echo 'hi'
  fi
}

json_data='{"a":10,"b":"2 0"}'

__load_global_params 1 "${json_data}"
echo "$(__get_param_type "${json_data}")"
 

# Call `_main` after everything has been defined.
_main "$@"

#"{a:10,b:20,c:manish}@delim=,;"