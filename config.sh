#!/bin/bash 

function config_get_value() {
    
    local value_type=$1
    local object_name=$2
    local value_name=$3
    local value="null"

    value=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".'${value_type}'[].'${object_name}'.'${value_name}'" /home/appuser/app/config.json')
    
    echo "$value"
}

function config_get_containers() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_CONTROL_CONTAINERS -eq 1 ]
    then
        log "Containers already loaded"
    else
        log "Get containers"

        for c in $(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".containers[] | keys | .[]" "/home/appuser/app/config.json"')
        do
            log "Add container $c"
            c="${c//$'\r'/}" #Remove unwanted cariage returns
            containers+=("${c}")
        done

        MC_CONTROL_CONTAINERS=1
    fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function config_get_container_values() {
    
    local container_name=$1
    local ret=

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Get configuration values for container \"$container_name\""

    local cnt=0
    for c in $(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".containers[].'${container_name}' | to_entries | map(\"\(.key)=\(.value|tostring)\") | .[]" /home/appuser/app/config.json')
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

function config_get_users() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_CONTROL_USERS -eq 1 ]
    then
        log "Users already loaded"
    else
        log "Get users"

        for u in $(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".users[] | keys | .[]" "/home/appuser/app/config.json"')
        do
            log "Add user $u"
            u="${u//$'\r'/}" #Remove unwanted cariage returns
            users+=("${u}")
        done

        MC_CONTROL_USERS=1
    fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function config_get_user_values() {
    
    local user_name=$1
    local ret=

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Get configuration values for user \"$user_name\""

    local cnt=0
    for u in $(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".users[].'${user_name}' | to_entries | map(\"\(.key)=\(.value|tostring)\") | .[]" /home/appuser/app/config.json')
    do
        if [ $cnt -gt 0 ]; then ret+=";"; fi
        u="${u//$'\r'/}" #Remove unwanted cariage returns
        ret+=${u}
        ((cnt++))
    done
    log "Found ${cnt} values"
    MC_LOGINDENT=$((MC_LOGINDENT-3))

    echo ${ret}
}

function config_get_userdefaultsettings() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_CONTROL_USERDEFAULTS -eq 1 ]
    then
        log "User default values already loaded"
    else
        log "Get user default values"

        MC_MAILDOMAIN=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".usersettings.MAILDOMAIN" /home/appuser/app/config.json')
        log "Maildomain \"$MC_MAILDOMAIN\""
        MC_DEFAULTPASSWORD=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".usersettings.DEFAULTPASSWORD" /home/appuser/app/config.json')
        log "Defaultpassword \"$MC_DEFAULTPASSWORD\""

        MC_CONTROL_USERDEFAULTS=1
    fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function config_get_certdefaultvalues() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_CONTROL_CERTDEFAULTS -eq 1 ]
    then
        log "Certificate default values already loaded"
    else
        log "Get certificate values"

        MC_CRTVALIDITY=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".certificates.VALIDITY" /home/appuser/app/config.json')
        log "Validity \"$MC_CRTVALIDITY\""
        MC_CRTCOUNTRY=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".certificates.COUNTRY" /home/appuser/app/config.json')
        log "Country \"$MC_CRTCOUNTRY\""
        MC_CRTSTATE=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".certificates.STATE" /home/appuser/app/config.json')
        log "State \"$MC_CRTSTATE\""
        MC_CRTLOCATION=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".certificates.LOCATION" /home/appuser/app/config.json')
        log "Location \"$MC_CRTLOCATION\""
        MC_CRTOU=$(docker run --name magicbuild --rm -i ${MC_PROJECT}/build sh -c 'jq -r ".certificates.OU" /home/appuser/app/config.json')
        log "OU \"$MC_CRTOU\""

        MC_CONTROL_CERTDEFAULTS=1
    fi

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
            log "replace \"${c}${param}\" with \"${value}\" in compose-file"
            sed -i -e "s/\#${c}${param}\#/${value}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
        done
    done

    log "set certificate values from configuration into compose file"
    sed -i -e "s/\#certificatesVALIDITY\#/${MC_CRTVALIDITY}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesCOUNTRY\#/${MC_CRTCOUNTRY}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesSTATE\#/${MC_CRTSTATE}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesLOCATION\#/${MC_CRTLOCATION}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    sed -i -e "s/\#certificatesOU\#/${MC_CRTOU}/g" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
