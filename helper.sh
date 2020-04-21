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
    MC_GITURL=https://github.com/Frickeldave

    #Properties overwritten by input parameters
    MC_STARTALL=0
    MC_RESETALL=0
    MC_CLEANALL=0
    MC_RESETIMAGE=0
    MC_STARTIMAGE=0
    MC_NOUPDATE=0
    MC_LOGBUILD=0
    MC_LOGSTART=0
    MC_CONFIGFILE=config
    MC_UPDATECONFIG=0

    # Certificate properties overwritten by configuration file
    MC_CRTVALIDITY="3650"
    MC_CRTCOUNTRY="DE"
    MC_CRTSTATE="BAVARIAN"
    MC_CRTLOCATION="ISMANING"
    MC_CRTOU="LOCALDEV"
    
    # User default values overwritten by configuration file
    MC_MAILDOMAIN="defaultmail.domain"
    MC_DEFAULTPASSWORD="defaultpassword"
    
    # TODO: Die MC_VAULT* Variablen müssen in die config.json Datein übernommen werden.
    MC_VAULTURL="https://127.0.0.1"
    MC_VAULTPORT="30105"
    MC_VAULTCONTAINER="vault"

    # Control variables used by several functions. Do not touch
    MC_CONTROL_USERS=0
    MC_CONTROL_USERDEFAULTS=0
    MC_CONTROL_CONTAINERS=0
    MC_CONTROL_CERTDEFAULTS=0
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
            --start-all)
                MC_STARTALL=1
                ;;
            --reset-all)
                MC_RESETALL=1
                ;;
            --clean-all)
                MC_CLEANALL=1
                ;;
            --reset-image)
                MC_RESETIMAGE=$value
                ;;
            --start-image)
                MC_STARTIMAGE=$value
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
            --config-file)
                MC_CONFIGFILE=$value
                ;;
            --update-config)
                MC_UPDATECONFIG=1
                ;;
            *) # Handles all unknown parameter 
                log "   Ignoring unknown parameter \"$param\""
                ;;
        esac
        shift
    done

    log "MC_PROJECT=$MC_PROJECT"
    log "MC_RESETALL=$MC_RESETALL"
    log "MC_CLEANALL=$MC_CLEANALL"
    log "MC_RESETIMAGE=$MC_RESETIMAGE"
    log "MC_LOGBUILD=$MC_LOGBUILD"
    log "MC_LOGSTART=$MC_LOGSTART"
    log "MC_CONFIGFILE=$MC_CONFIGFILE"
    log "MC_UPDATECONFIG=$MC_UPDATECONFIG"

    if [ "$MC_PROJECT" == "" ]; then log "\"Project\" not configured"; exit 1; fi

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
    echo " --start-all                    Start all container. \"--reset-all\" must be executed before."
    echo " --reset-all                    Renew all images. When images with same projectname exist, they will be deleted."
    echo " --clean-all                    Remove all project related images."
    echo " --reset-image=<IMAGENAME>      Reset/rebuild a single image."
    echo " --start-image=<IMAGENAME>      Start or restart a single image."
    echo " --no-update                    Prevents the update of the git repos."
    echo " --logbuild                     The output of \"docker-compose build\" is shown."
    echo " --logstart                     The output of \"docker-compose up\" is shown."
    echo " --config-file                  Set the target configuration file (defaults to \"config\")."
    echo " --update-config                Rebuild the \"build\" environment and update all configuration files."
    echo ""
    echo ""
    echo "Please make sure, that you added the following entries to your hosts file under"
    echo "  c:\windows\system32\drivers\etc"
    echo ""
    echo "   - 127.0.0.1   <project>.magic"
    echo "   - 127.0.0.1   gitea.<project>.magic"
    echo "   - 127.0.0.1   jenkins.<project>.magic"
    echo "   - 127.0.0.1   nexus.<project>.magic"
    echo "   - 127.0.0.1   docker.<project>.magic"
    echo "   - 127.0.0.1   keycloak.<project>.magic"
    echo "   - 127.0.0.1   vault.<project>.magic"
    echo ""
    echo ""
    echo "Servers and ports"
    echo ""
    echo "  name         ip address         ports"
    echo "-----------------------------------------"
    echo "  coredns        172.6.66.100     53"
    echo "  mariadbvault   172.6.66.102     30102"
    echo "  mariadb        172.6.66.103     30103"
    echo "  nginx          172.6.66.104     30104"
    echo "  Leberkas       172.6.66.109     30109"
    echo "  vault          172.6.66.105     30105"
    echo "  gitea          172.6.66.106     30106"
    echo "  jenkins        172.6.66.107     30107"
    echo "  keycloak       172.6.66.108     30108/30109/30110/30111/30112"
    echo "  nexus/docker   172.6.66.114     30114/58096"
    echo ""
    echo ""
    echo "Additional hints"
    echo ""
    echo " - This will not work when you use proxies which break your SSL connection (eg. ZSCaler)"
    echo ""
}
