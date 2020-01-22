#!/bin/bash 

function config_get_value() {
    
    local value_category=$1
    local value_name=$2
    local project_name=$3
    local value="null"

    value=$(docker run --name magicbuild --rm -it ${project_name}/build sh -c 'jq -r "'.$value_category.$value_name'" "/home/appuser/app/vault-init.json"')
    
    echo "$value"
}