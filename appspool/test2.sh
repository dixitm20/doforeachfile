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

f1 () {
    showConfigs "FUNCNAME"
    #echo ${FUNCNAME[1]}  # prints 'foo'
    #echo ${FUNCNAME[ 1 ]}  # prints 'bar'
    echo "f1"

}

f2 () {

    showConfigs2 
    echo "f2"
}



f4 () {
    local caller_script="$(caller | cut -d' ' -f2-)"
    local function_trace="$(getFuncCallTrace)"
    local function_signature="$( echo "'${caller_script}@${function_trace}: ${@}'" | sed "s/'\s*$/'/1" )"
    echo "param: ${#}"
    echo "f4"
}

f4

list="m an ni"
for arg in $list
do
    echo "$arg"
done