#!/bin/bash 

function config_get_value() {
    
    local value_category=$1
    local value_name=$2
    local value="null"

    value=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r "'.$value_category.$value_name'" "/home/appuser/app/vault-init.json"')
    
    echo "$value"
}

function config_get_containers() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    for c in $(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".containers[] | keys | .[]" "/home/appuser/app/vault-init.json"')
    do
        log "Add container $c"
        c="${c//$'\r'/}" #Remove unwanted cariage returns
        containers+=("${c}")
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function config_get_container_values() {
    
    local container_name=$1
    local ret=

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Get configuration values for container $c"

    local cnt=0
    for c in $(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".containers[].'${container_name}' | to_entries | map(\"\(.key)=\(.value|tostring)\") | .[]" /home/appuser/app/vault-init.json')
    do
        if [ $cnt -gt 0 ]; then ret+=";"; fi
        c="${c//$'\r'/}" #Remove unwanted cariage returns
        ret+=${c}
        ((cnt++))
    done
    log "Found ${cnt} values"
    MC_LOGINDENT=$((MC_LOGINDENT-3))

    echo ${ret}
}

function config_get_certificate_values() {
    
    local container_name=$1
    local ret=

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Get certificate values"

    MC_CRTVALIDITY=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".certificates.VALIDITY" /home/appuser/app/vault-init.json')
    log "Validity \"$MC_CRTVALIDITY\""
    MC_CRTCOUNTRY=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".certificates.COUNTRY" /home/appuser/app/vault-init.json')
    log "Country \"$MC_CRTCOUNTRY\""
    MC_CRTSTATE=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".certificates.STATE" /home/appuser/app/vault-init.json')
    log "State \"$MC_CRTSTATE\""
    MC_CRTLOCATION=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".certificates.LOCATION" /home/appuser/app/vault-init.json')
    log "Location \"$MC_CRTLOCATION\""
    MC_CRTOU=$(docker run --name magicbuild --rm -it ${MC_PROJECT}/build sh -c 'jq -r ".certificates.OU" /home/appuser/app/vault-init.json')
    log "OU \"$MC_CRTOU\""
    
    MC_LOGINDENT=$((MC_LOGINDENT-3))

}

function config_create_docker_compose_file() {
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "copy docker-compose template to home directory"
    cp -f "${MC_WORKDIR}/setup/dc-template.yml" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

    log "set project in compose file"
    sed -i -e "s/\#project\#/${MC_PROJECT}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

    for c in "${containers[@]}"
    do
        log "patch params for container \"${MC_PROJECT}/${c}\" into compose file"

        local container_values=$(config_get_container_values "$c")
        IFS=';' read -ra kvparr <<< "$container_values"    #Convert string to array

        for kvp in ${kvparr[@]}
        do
            local param=$(echo $kvp | awk -F= '{print $1}')
            local value=$(echo $kvp | awk -F= '{print $2}')
            log "replace \"${c}${param}\" with \"${value}\"" 
            sed -i -e "s/\#${c}${param}\#/${value}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
        done
    done

    log "set certificate values from configuration into compose file"
    config_get_certificate_values
    sed -i -e "s/\#certificatesVALIDITY\#/${MC_CRTVALIDITY}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesCOUNTRY\#/${MC_CRTCOUNTRY}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesSTATE\#/${MC_CRTSTATE}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesLOCATION\#/${MC_CRTLOCATION}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesOU\#/${MC_CRTOU}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
