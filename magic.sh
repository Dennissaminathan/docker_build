#!/bin/sh

MC_WORKDIR=$(dirname "$(readlink -f "$0")")
declare -a containers
declare -a users

source $MC_WORKDIR/helper.sh
source $MC_WORKDIR/docker.sh
source $MC_WORKDIR/vault.sh
source $MC_WORKDIR/config.sh
source $MC_WORKDIR/keycloak.sh
source $MC_WORKDIR/gitea.sh

function magic_main() {

    helper_set_variables

    helper_parse_parameter $@

    if [ $MC_STARTALL -eq 1 ]
    then 
        magic_start_all

    elif [ ! "$MC_RESETIMAGE" == "0" ]
    then 
        log "test internet"
        helper_test_internet

        magic_reset_image $MC_RESETIMAGE

    elif [ ! "$MC_STARTIMAGE" == "0" ]
    then 
        log "test internet"
        helper_test_internet

        magic_start_image $MC_STARTIMAGE

    elif [ $MC_RESETALL -eq 1 ]
    then 
        log "test internet"
        helper_test_internet

        config_get_certificate_values

        config_get_usersettings

        magic_reset_all $@

    elif [ $MC_CLEANALL -eq 1 ]
    then 
        log "test internet"
        helper_test_internet

        magic_clean_all $@

        docker system prune -f
    
    elif [ $MC_UPDATECONFIG -eq 1 ]
    then 
        config_get_certificate_values

        magic_update_config
    else
        log "No action selected."
    fi
}

function magic_start_all() {

    log "docker start all"
    docker_start_all
}

function magic_reset_image() {

    local docker_image=$1

    case $docker_image in
        alpine)
            magic_reset_image_helper $docker_image
            ;;
        vault)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        mariadb)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        mariadbvault)
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
        build)
            magic_reset_image_helper $docker_image
            ;;
        nginx)
            config_get_certificate_values
            magic_reset_image_helper $docker_image
            ;;
        leberkas)
            config_get_certificate_values
            magic_reset_image_helper $docker_image
            ;;
        coredns)
            magic_reset_image_helper $docker_image
            ;;
        gitea)
            config_get_certificate_values
            config_get_usersettings
            
            magic_reset_image_helper $docker_image
            
            log "get the list of users from the configuration file"
            config_get_users

            log "Setup gitea initally"
            gitea_initial_setup
            ;;
        jenkins)
            config_get_certificate_values

            magic_reset_image_helper $docker_image
            ;;
        keycloak)
            config_get_certificate_values
            config_get_usersettings
            magic_reset_image_helper $docker_image
            log "get the list of users from the configuration file"
            config_get_users

            log "Setup keycloak initally"
            keycloak_initial_setup
            ;;
        nexus)
            config_get_certificate_values
            config_get_usersettings
            magic_reset_image_helper $docker_image
            ;;
        *) # Handles all unknown parameter 
            log "   Ignoring unsupported docker image \"$docker_image\""
            ;;
    esac
    shift
}

function magic_start_image() {

    local docker_image=$1

    case $docker_image in
        alpine)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        vault)
            log "single rebuild not supported, run magic.sh without params"
            exit 0
            ;;
        mariadb)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        mariadbvault)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        go)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        jre8)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        jre11)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        jdk8)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        jdk11)
            log "single start not supported, is just a base image for other containers"
            exit 0
            ;;
        build)
            magic_start_image_helper $docker_image
            ;;
        nginx)
            magic_start_image_helper $docker_image
            ;;
        coredns)
            magic_start_image_helper $docker_image
            ;;
        gitea)
            magic_start_image_helper $docker_image
            ;;
        jenkins)
            magic_start_image_helper $docker_image
            ;;
        keycloak)
            magic_start_image_helper $docker_image
            ;;
        nexus)
            magic_start_image_helper $docker_image
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
    helper_git_download "${MC_GITURL}/docker_${docker_image}" "docker_$docker_image"

    log "docker build"
    docker_build "$docker_image" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    log "start container"
	docker_start $docker_image

    if [ $MC_LOGSTART == 1 ]
    then 
        docker logs ${MC_PROJECT}_${docker_image}_1
    fi
}

function magic_start_image_helper() {
    local docker_image=$1

    log "stop docker-container \"${docker_image}\""
    docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d ${docker_image} > /dev/null 2>&1

    log "start container"
	docker_start $docker_image
}

function magic_reset_all() {

    log "docker clean all"
    docker_clean_all

    log "Update the configuration files by building the \"\build\" environment"
    magic_update_config
    
    log "download or update all needed git repos"
    helper_git_download_all

    log "Build mariadb, go and vault image"
	docker_build "go" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "mariadb" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "vault" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

    log "start mariadb"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d mariadbvault > /dev/null 2>&1
	log "start vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d vault > /dev/null 2>&1

    log "get the root token out of the vault docker container"
    local root_token=$(vault_get_root_token "$MC_VAULTCONTAINER")
    
    log "check if vault is running and unsealed and unseal if needed"
    vault_check_status "$root_token"

    log "Create a kv_v2 secret store for the project, activate approle and userpass authentication, create admin policies"
    vault_init "$root_token"

    log "Write secrets from json to vault-server"
    vault_add_secrets "$root_token"
   
    log "stop vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d vault > /dev/null 2>&1
	log "stop mariadb"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d mariadbvault > /dev/null 2>&1

    log "docker build all"
    docker_build_all

    log "docker start all"
    docker_start_all

    log "get user default settings"
    config_get_userdefaultsettings

    log "get the list of users from the configuration file"
    config_get_users

    log "Setup keycloak initally"
    keycloak_initial_setup

    log "docker system prune"
    docker system prune -f  > /dev/null 2>&1
}

function magic_update_config() {

    log "download or update files needed for build process"
    helper_git_download ${MC_GITURL}/docker_alpine "docker_alpine"

    log "build the \"build\" container"
    docker_build_setup

    log "get the list of containers from the configuration file"
    config_get_containers

    log "config create docker compose file"
    config_create_docker_compose_file
}

magic_main $@

finishtime=`date +%Y-%m-%d_%H:%M:%S`
log "Finished at \"$finishtime\""

