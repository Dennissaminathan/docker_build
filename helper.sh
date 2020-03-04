#!/bin/bash 

function log() {
    
    local message=$1

    if [ "$MC_LOG" == "1" ]
    then
        s=$(printf "%-${MC_LOGINDENT}s" " ")
        echo "${s// / } ${message}" >&2
    fi
}

function set_variables() {

    MC_LOG=1
    MC_LOGINDENT=0
    MC_SKIPBUILD=0
    MC_SKIPSETUP=0
    # TODO: Die MC_VAULT* Variablen müssen in die vault-init.json Datein übernommen werden.
    MC_VAULTURL="https://127.0.0.1"
    MC_VAULTPORT="10443"
    MC_VAULTCONTAINER="vault"
}

function test_internet() {
    local test_url=google.com
    local test_result=0
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    curl -sSf $test_url > /dev/null
    if [ "$?" == "0" ]
    then 
        log "Internet connection available"
        MC_LOGINDENT=$((MC_LOGINDENT-3))
    else
        log "Internet connection not available"
        MC_LOGINDENT=$((MC_LOGINDENT-3))
    fi

}

function parse_parameter() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    while [ "$1" != "" ]
    do
        local param=$(echo $1 | awk -F= '{print $1}')
        local value=$(echo $1 | awk -F= '{print $2}')

        case $param in

            --project) 
                MC_PROJECT=$value
                log "MC_PROJECT=$MC_PROJECT"
                ;;
            --skip-build)
                MC_SKIPBUILD=1
                log "\"skip-build\" given. Skip all build steps"
                ;;
            --skip-setup)
                MC_SKIPSETUP=1
                log "\"skip-setup\" given. Skip all setup steps"
                ;;
            *) # Handles all unknown parameter 
                log "   Ignoring unknown parameter \"$param\""
                ;;
        esac
        shift
    done

    if [ "$MC_PROJECT" == "" ]; then log "\"Project\" not configured"; exit 1; fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
