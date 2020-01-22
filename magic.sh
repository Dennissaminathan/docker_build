#!/bin/sh

MC_CLEAN="true"
MC_BUILD="true"
MC_STAGE1="true"
MC_VAULTINIT="true"
MC_SECRET="true"
MC_AUTH="true"
MC_STAGE2="true"
MC_PROJECT="frickeldave"
MC_VAULTURL="https://127.0.0.1"
MC_VAULTPORT="10443"
MC_VAULTCONTAINER="vault"
HL_LOG=1
MC_WORKDIR=$(dirname "$(readlink -f "$0")")

source $(dirname "$(readlink -f "$0")")/helper.sh
source $(dirname "$(readlink -f "$0")")/docker.sh
source $(dirname "$(readlink -f "$0")")/vault.sh
source $(dirname "$(readlink -f "$0")")/config.sh

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
    log "### startup systems - Stage 1"
    log "#####################################################################"
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d mariadbvault > /dev/null 2>&1
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d vault > /dev/null 2>&1
fi

root_token=$(vault_get_root_token "$MC_PROJECT" "$MC_VAULTCONTAINER")

if [ "$MC_VAULTINIT" == "true" ] 
then 
    log "#####################################################################"
    log "### configure vault server"
    log "#####################################################################" 

    vault_check_status "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"

    vault_init "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"
fi 

if [ "$MC_SECRET" == "true" ] 
then
    echo "#####################################################################"
    echo "### Add secrets to vault server"
    echo "#####################################################################" 
    vault_add_secrets "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token"
fi

if [ "$MC_AUTH" == "true" ] 
then
    echo "#####################################################################"
    echo "### Add vault policies and roles"
    echo "#####################################################################" 
    vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "certificates"
    vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "mariadb"
    vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "vault"
    vault_write_apppolicy "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "gitea"
    vault_write_approle "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "mariadb"
    vault_write_approle "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "vault"
    vault_write_approle "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "gitea"
fi

role_id=$(vault_get_role_id  "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "mariadb")
secret_id=$(vault_get_secret_id  "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "mariadb")
apptoken=$(vault_get_apptoken "$MC_PROJECT" "$MC_VAULTCONTAINER" "$MC_VAULTURL" "$MC_VAULTPORT" "$root_token" "$role_id" "$secret_id")

if [ "$MC_STAGE2" == "true" ] 
then
    echo "#####################################################################"
    echo "### startup systems - Stage 2"
    echo "#####################################################################"
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d mariadb #> /dev/null 2>&1
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d nginx #> /dev/null 2>&1
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d coredns #> /dev/null 2>&1
    docker-compose -f ./docker-compose.yml --project-name "$MC_PROJECT" up -d gitea #> /dev/null 2>&1
fi 

docker system prune -f