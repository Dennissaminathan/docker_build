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

function main() {

    log "set variables"
    set_variables

    log "parse parameter"
    parse_parameter $@

    log "test internet"
    test_internet

    log "docker clean"
    docker_clean

    log "download files needed for build process"
    git_download https://github.com/Frickeldave/docker_alpine "docker_alpine"

    log "docker build setup"
    docker_build_setup

    log "config get containers"
    config_get_containers
    
    log "download all needed git repos"
    git_download_all

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

main $@