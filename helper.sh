#!/bin/bash 

function log() {
    if [ "$HL_LOG" == "1" ]
    then
        echo $1 >&2
    fi
}

function set_variables() {
    
    HL_LOG=1

    log "#####################################################################"
    log "### Control variables for build process"
    log "#####################################################################"
    MC_CLEAN="true"
    MC_BUILD="true"
    MC_STAGE1="true"
    MC_VAULTINIT="true"
    MC_SECRET="true"
    MC_AUTH="true"
    MC_STAGE2="true"
    log "MC_CLEAN=$MC_CLEAN"
    log "MC_BUILD=$MC_BUILD"
    log "MC_STAGE1=$MC_STAGE1"
    log "MC_VAULTINIT=$MC_VAULTINIT"
    log "MC_SECRET=$MC_SECRET"
    log "MC_AUTH=$MC_AUTH"
    log "MC_STAGE2=$MC_STAGE2"

    log "#####################################################################"
    log "### Variables used for development (should be set to true)"
    log "#####################################################################"
    MC_PROJECT=""
    MC_VAULTURL="https://127.0.0.1"
    MC_VAULTPORT="10443"
    MC_VAULTCONTAINER="vault"
    log "MC_PROJECT=$MC_PROJECT"
    log "MC_VAULTURL=$MC_VAULTURL"
    log "MC_VAULTPORT=$MC_VAULTPORT"
    log "MC_VAULTCONTAINER=$MC_VAULTCONTAINER"
}

function test_internet() {
    local test_url=google.com
    local test_result=0
    
    curl -sSf $test_url > /dev/null
    if [ "$?" == "0" ]
    then 
        log "Internet connection available"
    else
        log "Internet connection not avialable"
    fi
}

function parse_parameter() {

    log "#####################################################################"
    log "### parse parameter"
    log "#####################################################################"

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
                MC_CLEAN="false"
                MC_BUILD="false"
                MC_STAGE1="false"
                MC_VAULTINIT="false"
                MC_STAGE2="false"
                log "\"skip-build\" given. Skip all build steps"
                ;;
            --skip-secret)
                MC_SECRET="false"
                log "\"skip-secret\" given. Skip all secret steps"
                ;;
            *) # Handles all unknown parameter
                log "   Ignoring unknown parameter \"$param\""
                ;;
        esac
        shift
    done

    if [ "$MC_PROJECT" == "" ]; then log "\"Project\" not configured"; exit 1; fi
}