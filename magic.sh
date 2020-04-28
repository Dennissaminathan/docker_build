#!/bin/sh

MC_WORKDIR=$(dirname "$(readlink -f "$0")")
declare -a containers
declare -a users
declare -a groups

source $MC_WORKDIR/helper.sh
source $MC_WORKDIR/docker.sh
source $MC_WORKDIR/vault.sh
source $MC_WORKDIR/config.sh
source $MC_WORKDIR/keycloak.sh
source $MC_WORKDIR/gitea.sh
source $MC_WORKDIR/obazda.sh

function magic_main() {

    helper_set_variables

    helper_parse_parameter $@

    if [ $MC_STARTALL -eq 1 ]
    then 
        magic_start_all

    elif [ ! "$MC_RESETIMAGE" == "0" ]
    then 
        magic_reset_image $MC_RESETIMAGE

    elif [ ! "$MC_STARTIMAGE" == "0" ]
    then 
        magic_start_image $MC_STARTIMAGE

    elif [ $MC_RESETALL -eq 1 ]
    then 
        magic_reset_all $@

    elif [ $MC_CLEANALL -eq 1 ]
    then 
        magic_clean_all $@

    elif [ $MC_UPDATECONFIG -eq 1 ]
    then 
        magic_update_config
    else
        log "No action selected."
    fi
}

function magic_start_all() {

	log "start mariadb"
	docker_start "mariadb"
	log "start vault"
	docker_start "vault"
    log "start nginx"
	docker_start "nginx"
    log "start coredns"
	docker_start "coredns"
    log "start keycloak"
	docker_start "keycloak"
	log "start leberkas"
	docker_start "leberkas"
    log "start obazda"
	docker_start "obazda"
	log "start gitea"
	docker_start "gitea"
	log "start jenkins"
	docker_start "jenkins"
	log "start nexus"
	docker_start "nexus"
}

function magic_reset_image() {

    local docker_image=$1

    log "test internet"
    helper_test_internet

    case $docker_image in
        alpine)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        build)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        mariadb)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        go)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        vault)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Reset the image"
            magic_reset_image_helper $docker_image

            log "Setup vault initially"
            vault_initial_setup
            ;;
        jre8)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        jre11)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        jdk8)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        jdk11)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        nginx)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        coredns)
            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        keycloak)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Get user default values from the configuration file"
            config_get_userdefaultsettings

            log "Reset the image"
            magic_reset_image_helper $docker_image

            log "get the list of users from the configuration file"
            config_get_users

            log "Setup keycloak initally"
            keycloak_initial_setup
            ;;
        leberkas)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        obazda)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Get user default values from the configuration file"
            config_get_userdefaultsettings

            log "Reset the image"
            magic_reset_image_helper $docker_image

            log "get the list of users from the configuration file"
            config_get_users

            log "get the list of groups from the configuration file"
            config_get_groups

            log "Setup obazda initally"
            obazda_initial_setup
            ;;
        gitea)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Get user default values from the configuration file"
            config_get_userdefaultsettings
            
            log "Reset the image"
            magic_reset_image_helper $docker_image
            
            log "get the list of users from the configuration file"
            config_get_users

            log "Setup gitea initally"
            gitea_initial_setup
            ;;
        jenkins)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Reset the image"
            magic_reset_image_helper $docker_image
            ;;
        nexus)
            log "Get certificate default values from the configuration file"
            config_get_certdefaultvalues

            log "Get user default values from the configuration file"
            config_get_userdefaultsettings

            log "Reset the image"
            magic_reset_image_helper $docker_image

	    log "Setup nexus initially"
            nexus_initial_setup
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
    
    download_docker_image_name=${docker_image}
    # Handle special situation for java
    if [ "$docker_image" == "jre8" ] || [ "$docker_image" == "jdk8" ] || [ "$docker_image" == "jre11" ] || [ "$docker_image" == "jdk11" ]
    then 
        download_docker_image_name="java"
    fi

    log "Refresh files"
    helper_git_download "${MC_GITURL}/docker_${download_docker_image_name}" "docker_${download_docker_image_name}"

    log "docker build"
    docker_build "$docker_image" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
    log "start container"
	docker_start $docker_image

    if [ $MC_LOGSTART == 1 ]
    then 
        docker logs ${MC_PROJECT}_${docker_image}_1
    fi
}

function magic_start_image() {

    local docker_image=$1

    # The following case statement is a bit stupid, but it is predefined to add statements that are needed during startup
    case $docker_image in
        alpine)
            magic_start_image_helper $docker_image
            ;;
        build)
            magic_start_image_helper $docker_image
            ;;
        mariadb)
            magic_start_image_helper $docker_image
            ;;
        go)
            magic_start_image_helper $docker_image
            ;;
        vault)
            magic_start_image_helper $docker_image
            ;;
        jre8)
            magic_start_image_helper $docker_image
            ;;
        jre11)
            magic_start_image_helper $docker_image
            ;;
        jdk8)
            magic_start_image_helper $docker_image
            ;;
        jdk11)
            magic_start_image_helper $docker_image
            ;;
        nginx)
            magic_start_image_helper $docker_image
            ;;
        coredns)
            magic_start_image_helper $docker_image
            ;;
        keycloak)
            magic_start_image_helper $docker_image
            ;;
        leberkas)
            magic_start_image_helper $docker_image
            ;;
        obazda)
            magic_start_image_helper $docker_image
            ;;
        gitea)
            magic_start_image_helper $docker_image
            ;;
        jenkins)
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

function magic_start_image_helper() {
    local docker_image=$1

    log "stop docker-container \"${docker_image}\""
    docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d ${docker_image} > /dev/null 2>&1

    log "start container"
	docker_start $docker_image
}

function magic_clean_all() {
    
    log "test internet"
    helper_test_internet

    docker_clean "alpine"
	docker_clean "build"
    docker_clean "mariadb"
	docker_clean "go"
    docker_clean "vault"
    docker_clean "jre8"
    docker_clean "jre11"
    docker_clean "jdk8"
	docker_clean "jdk11"
	docker_clean "nginx"
	docker_clean "coredns"
	docker_clean "keycloak"
	docker_clean "leberkas"
    docker_clean "obazda"
	docker_clean "gitea"
	docker_clean "jenkins"
	docker_clean "nexus"
	docker system prune -f
}

function magic_download_all() {

    helper_git_download "${MC_GITURL}/docker_alpine" "docker_alpine"
    helper_git_download "${MC_GITURL}/docker_build" "docker_build"
    helper_git_download "${MC_GITURL}/docker_mariadb" "docker_mariadb"
    helper_git_download "${MC_GITURL}/docker_go" "docker_go"
    helper_git_download "${MC_GITURL}/docker_vault" "docker_vault"
    helper_git_download "${MC_GITURL}/docker_java" "docker_java"
    helper_git_download "${MC_GITURL}/docker_nginx" "docker_nginx"
    helper_git_download "${MC_GITURL}/docker_coredns" "docker_coredns"
    helper_git_download "${MC_GITURL}/docker_keycloak" "docker_keycloak"
    helper_git_download "${MC_GITURL}/docker_leberkas" "docker_leberkas"
    helper_git_download "${MC_GITURL}/docker_obazda" "docker_obazda"
    helper_git_download "${MC_GITURL}/docker_gitea" "docker_gitea"
    helper_git_download "${MC_GITURL}/docker_jenkins" "docker_jenkins"
    helper_git_download "${MC_GITURL}/docker_nexus" "docker_nexus"
}

function magic_reset_all() {

    log "test internet"
    helper_test_internet

    log "docker clean all"
    magic_clean_all

    log "Update the configuration files by building the \"build\" environment"
    magic_update_config

    log "get certificate values from configuration file"
    config_get_certdefaultvalues

    log "get usersettings from configuration file"
    config_get_userdefaultsettings

    log "get user default settings"
    config_get_userdefaultsettings

    log "Refresh all sources" 
    # TODO: dc_file_not_found 
    # This is just implemented, bacause docker_compose doesnt run, when not all referenced files are available and the next step (Build go) will fail, bacause ogf missing java sources.
    # ERROR: build path C:\Users\david\Documents\dc2go_test\docker_java either does not exist, is not accessible, or is not a valid URL.
    # Later we have to find out, if docker_compose can be configured to ignore a missing directory or we have to split the compose file
    magic_download_all

    log "Build mariadb"
    magic_reset_image "mariadb"

    log "Build go"
    magic_reset_image "go"
    
    log "Build vault"
    magic_reset_image "vault"

    log "build all other images"
    magic_reset_image "jre8"
    magic_reset_image "jre11"
    magic_reset_image "jdk8"
    magic_reset_image "jdk11"
    magic_reset_image "nginx"
    magic_reset_image "coredns"
    magic_reset_image "keycloak"
    magic_reset_image "leberkas"
    #magic_reset_image "obazda"
    magic_reset_image "gitea"
    magic_reset_image "jenkins"
    magic_reset_image "nexus"

    log "docker system prune"
    docker system prune -f  > /dev/null 2>&1
}

function magic_update_config() {

    log "download or update files needed for build process"
    helper_git_download ${MC_GITURL}/docker_alpine "docker_alpine"

    log "build the \"build\" container"
    docker_build_setup

    log "download certificate values"
    config_get_certdefaultvalues

    log "get the list of containers from the configuration file"
    config_get_containers

    log "config create docker compose file"
    config_create_docker_compose_file
}

magic_main $@

finishtime=`date +%Y-%m-%d_%H:%M:%S`
log "Finished at \"$finishtime\""

