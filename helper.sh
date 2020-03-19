#!/bin/bash 

function log() {
    
    local message=$1

    if [ "$MC_LOG" == "1" ]
    then
        s=$(printf "%-${MC_LOGINDENT}s" " ")
        echo "${s// / } ${message}" >&2
    fi
}

function helper_set_variables() {
    # Static poroperties
    MC_LOG=1
    MC_LOGINDENT=0

    #Properties overwritten by input parameters
    MC_START=0
    MC_RESETALL=0
    MC_RESETIMAGE=0
    MC_NOUPDATE=0
    MC_LOGBUILD=0
    MC_LOGSTART=0

    # Certificate proerties overwritten by configuration file
    MC_CRTVALIDITY="3650"
    MC_CRTCOUNTRY="DE"
    MC_CRTSTATE="BAVARIAN"
    MC_CRTLOCATION="HOERGERTSHAUSEN"
    MC_CRTOU="LOCALDEV"

    # TODO: Die MC_VAULT* Variablen müssen in die vault-init.json Datein übernommen werden.
    MC_VAULTURL="https://127.0.0.1"
    MC_VAULTPORT="30105"
    MC_VAULTCONTAINER="vault"
}

function helper_test_internet() {
    local test_url=google.com
    local test_result=0
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    ping -w 1 -n 1 $test_url > /dev/null
    if [ $? -eq 0 ]
    then 
        log "Internet connection available"
        MC_LOGINDENT=$((MC_LOGINDENT-3))
    else
        log "Internet connection not available"
        MC_LOGINDENT=$((MC_LOGINDENT-3))
    fi

}

function helper_parse_parameter() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    while [ "$1" != "" ]
    do
        local param=$(echo $1 | awk -F= '{print $1}')
        local value=$(echo $1 | awk -F= '{print $2}')

        case $param in
            --help) 
                helper_usage
                exit 0
                ;;
            --project) 
                MC_PROJECT=$value
                ;;
            --start)
                MC_START=1
                ;;
            --reset-all)
                MC_RESETALL=1
                ;;
            --reset-image)
                MC_RESETIMAGE=$value
                ;;
            --no-update)
                MC_NOUPDATE=1
                ;;    
            --logbuild)
                MC_LOGBUILD=1
                ;;
            --logstart)
                MC_LOGSTART=1
                ;;
            *) # Handles all unknown parameter 
                log "   Ignoring unknown parameter \"$param\""
                ;;
        esac
        shift
    done

    log "MC_PROJECT=$MC_PROJECT"
    log "MC_RESETALL=$MC_RESETALL"
    log "MC_RESETIMAGE=$MC_RESETIMAGE"
    log "MC_LOGBUILD=$MC_LOGBUILD"
    log "MC_LOGSTART=$MC_LOGSTART"

    if [ "$MC_PROJECT" == "" ]; then log "\"Project\" not configured"; exit 1; fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function helper_git_download_all() {
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_NOUPDATE -eq 0 ]
    then
        log "start git update"
        helper_git_download https://github.com/Frickeldave/docker_go "docker_go"
        helper_git_download https://github.com/Frickeldave/docker_nginx "docker_nginx"
        helper_git_download https://github.com/Frickeldave/docker_coredns "docker_coredns"
        helper_git_download https://github.com/Frickeldave/docker_mariadb "docker_mariadb"
        helper_git_download https://github.com/Frickeldave/docker_vault "docker_vault"
        helper_git_download https://github.com/Frickeldave/docker_gitea "docker_gitea"
        helper_git_download https://github.com/Frickeldave/docker_java "docker_java"
        helper_git_download https://github.com/Frickeldave/docker_jenkins "docker_jenkins"
        helper_git_download https://github.com/Frickeldave/docker_sambadc "docker_sambadc"
    else
        log "skip git update"
    fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function helper_git_download() {
    local giturl=$1
    local gittarget=$2

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    if [ $MC_NOUPDATE -eq 0 ]
    then
        log "Get files from ${giturl}"
        if [ -d "${MC_WORKDIR}/../${gittarget}/.git" ]
        then
            log "Target directory already exist. Doing pull."
            pushd "${MC_WORKDIR}/../${gittarget}"

            git pull $giturl master > /dev/null 2>&1
            if [ $? -eq 0 ]
            then 
                log "git pull successful"
                popd
            else
                log "git pull failed"
                popd
                exit 1
            fi
        else
            log "Target directory doesn't exist. Doing clone."
            git clone "${giturl}" "${MC_WORKDIR}/../${gittarget}" > /dev/null 2>&1
            if [ $? -eq 0 ]
            then 
                log "git clone successful"
            else
                log "git clone failed"
                exit 1
            fi
        fi
    else
        log "git update disabled"
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function helper_usage() {
    
    echo ""
    echo "Usage: ./magic.sh --project=<projectname> [OPTION]"
    echo ""
    echo " --help                         Show this screen."
    echo " --project=<PROJECTNAME>        Mandatory. The projectname defines containername, imagename, filename, ..."
    echo " --start                        Start container. \"--reset-all\" must be executed before."
    echo " --reset-all                    Renew all images. When images with same projectname exist, they will be deleted."
    echo " --reset-image=<IMAGENAME>      Reset a single image."
    echo " --no-update                    Prevents the update of the git repos."
    echo " --logbuild                     The output of \"docker-compose build\" is shown."
    echo " --logstart                     The output of \"docker-compose up\" is shown."
    echo ""
    echo "Servers and ports"
    echo "  name         ip address         ports"
    echo "-----------------------------------------"
    echo "  coredns        172.6.66.100     53"
    echo "  sambadc        172.6.66.101     several"
    echo "  mariadbvault   172.6.66.102     30102"
    echo "  mariadb        172.6.66.103     30103"
    echo "  nginx          172.6.66.104     30104"
    echo "  vault          172.6.66.105     30105"
    echo "  gitea          172.6.66.106     30106"
    echo "  jenkins        172.6.66.107     30107"
    echo "  nexus/docker   172.6.66.108     30108/58096"
}
