#!/bin/sh

#examples: 
#       Run the whole process
#       ./magic.sh --project="frickeldave"
#
#       FOR DEVELOPMENT: Skip the image build process
#       ./magic.sh --project="frickeldave" --skip-build
#
#       FOR DEVELOPMENT: Skip the image build process as well as the setup process
#       ./magic.sh --project="frickeldave" --skip-build --skip-setup


            #docker-compose.exe -f ./docker-compose-build.yml build build

MC_WORKDIR=$(dirname "$(readlink -f "$0")")
declare -a containers

source $MC_WORKDIR/helper.sh
source $MC_WORKDIR/docker.sh
source $MC_WORKDIR/vault.sh
source $MC_WORKDIR/config.sh

function magic_main() {

    helper_set_variables

    helper_parse_parameter $@

    log "test internet"
    helper_test_internet

    if [ ! "$MC_RESETIMAGE" == "0" ]; then magic_reset_image $MC_RESETIMAGE; fi
    if [ "$MC_RESETALL" == "1" ]; then magic_default $@; fi
    
    log "Finished"
}

function magic_reset_image() {

    local docker_image=$1

    case $docker_image in
        alpine)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        vault)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        mariadb)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        go)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        jre8)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        jre11)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        jdk8)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        jdk11)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        nginx)
            magic_reset_image_helper $docker_image
            ;;
        coredns)
            magic_reset_image_helper $docker_image
            ;;
        gitea)
            magic_reset_image_helper $docker_image
            ;;
        jenkins)
            magic_reset_image_helper $docker_image
            ;;
        *) # Handles all unknown parameter 
            log "   Ignoring unsupported docker image \"$docker_image\""
            ;;
    esac
    shift
}

function magic_reset_image_helper() {
    local docker_image=$1

    log "docker clean system from container and related data for \"${docker_image}\""
    docker_clean "$docker_image"
    log "Refresh files"
    helper_git_download "https://github.com/Frickeldave/docker_${docker_image}" "docker_$docker_image"
    log "docker build"
    docker_build "$docker_image" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    log "start container"
	docker_start $docker_image
}

function magic_default() {

    log "docker clean all"
    docker_clean_all

    log "download files needed for build process"
    helper_git_download https://github.com/Frickeldave/docker_alpine "docker_alpine"

    log "docker build setup"
    docker_build_setup

    log "config get containers"
    config_get_containers
    
    log "download all needed git repos"
    helper_git_download_all

    log "config create docker compose file"
    config_create_docker_compose_file

    log "docker system prune"
    docker system prune -f  > /dev/null 2>&1

    log "docker build vault"
    docker_build_vault

    log "docker start vault"
    docker_start_vault

    log "get the root token out of the docker container"
    local root_token=$(vault_get_root_token "$MC_VAULTCONTAINER")
    
    log "check if vault is running and unsealed and unseal if needed"
    vault_check_status "$root_token"

    log "Create a kv_v2 secret store for the project, activate approle and userpass authentication, create admin policies"
    vault_init "$root_token"

    log "Write secrets from json to vault-server"
    vault_add_secrets "$root_token"
   
    log "docker vault stop"
    docker_vault_stop

    log "docker build all"
    docker_build_all

    log "docker start all"
    docker_start_all
}

magic_main $@