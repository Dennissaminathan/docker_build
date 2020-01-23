#!/bin/sh

MC_WORKDIR=$(dirname "$(readlink -f "$0")")

source $MC_WORKDIR/helper.sh
source $MC_WORKDIR/docker.sh
source $MC_WORKDIR/vault.sh
source $MC_WORKDIR/config.sh

function main() {

    set_variables

    parse_parameter $@

    test_internet

    if [ $MC_CLEAN == "true" ]
    then
        log "#####################################################################"
        log "### remove existing images, volumes and container"
        log "#####################################################################"

        docker_remove "$MC_PROJECT" "alpine"
        docker_remove "$MC_PROJECT" "build"
        docker_remove "$MC_PROJECT" "go"
        docker_remove "$MC_PROJECT" "nginx"
        docker_remove "$MC_PROJECT" "coredns"
        docker_remove "$MC_PROJECT" "mariadb"
        docker_remove "$MC_PROJECT" "mariadbvault"
        docker_remove "$MC_PROJECT" "vault"
        docker_remove "$MC_PROJECT" "gitea"
    fi

    if [ "$MC_BUILD" == "true" ] 
    then
        log "#####################################################################"
        log "### build systems"
        log "#####################################################################"
        docker_build "$MC_PROJECT" "alpine" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "build" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "go" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "mariadb" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "vault" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "nginx" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "coredns" "./docker-compose.yml"
        docker_build "$MC_PROJECT" "gitea" "./docker-compose.yml"
    fi

    if [ "$MC_STAGE1" == "true" ] 
    then
        log "#####################################################################"
        log "### startup systems - Stage 1 - Vault core"
        log "#####################################################################"
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d mariadbvault > /dev/null 2>&1
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d vault > /dev/null 2>&1
    fi

    local root_token=$(vault_get_root_token "$MC_PROJECT" "$MC_VAULTCONTAINER")

    vault_check_status "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"

    if [ "$MC_VAULTINIT" == "true" ] 
    then 
        log "#####################################################################"
        log "### configure vault server"
        log "#####################################################################" 

        vault_init "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"
    fi 

    if [ "$MC_STAGE2" == "true" ] 
    then
        log "#####################################################################"
        log "### startup systems - Stage 2"
        log "#####################################################################"
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d mariadb > /dev/null 2>&1
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d nginx > /dev/null 2>&1
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d coredns > /dev/null 2>&1
        docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d gitea > /dev/null 2>&1
    fi

    docker system prune -f

    if [ "$MC_SECRET" == "true" ] 
    then
        log "#####################################################################"
        log "### Add secrets to vault server"
        log "#####################################################################" 
        vault_add_secrets "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"
    fi

    if [ "$MC_AUTH" == "true" ] 
    then
        log "#####################################################################"
        log "### Add vault policies and roles"
        log "#####################################################################" 
        vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "certificates"
        
        containers=( "mariadb" "vault" "gitea" )
        for i in "${containers[@]}"
        do
            vault_write_approle "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "$i"
            vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "$i"
            local role_id=$(vault_get_role_id "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "$i")
            docker_write_roleid "$MC_PROJECT" "$i" "$role_id"
        done

    fi

    

    
    #apptoken=$(vault_get_apptoken "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "$role_id" "$secret_id")

    
}

main $@