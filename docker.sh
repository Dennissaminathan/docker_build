#!/bin/bash

function docker_clean() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))
	#TODO: Replace with dynamic list from vault-init.json
	docker_remove "alpine"
	docker_remove "build"
	docker_remove "go"
	docker_remove "nginx"
	docker_remove "coredns"
	docker_remove "mariadb"
	docker_remove "mariadbvault"
	docker_remove "vault"
	docker_remove "gitea"
	docker_remove "jdk11"
	docker_remove "jre11"
	docker_remove "jre8"
	docker_remove "jdk8"
	docker_remove "jenkins"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build_setup() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	echo "version: "\'"3.7"\'"" > "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	echo "services:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
  	echo "  alpine:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
    echo "    build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      dockerfile: Dockerfile-alpine" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      context: ./../docker_alpine" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "    image: ${MC_PROJECT}/alpine:latest" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
  	echo "  build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
    echo "    build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      dockerfile: Dockerfile-build" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      context: ." >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "    image: ${MC_PROJECT}/build:latest"   >> "${MC_WORKDIR}/docker-compose-setupbuild.yml" 

	docker_build_image "alpine" "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	docker_build_image "build" "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	rm -f "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build_vault() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "Build mariadb, go and vault image"
	docker_build_image "go" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build_image "mariadb" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build_image "vault" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build_all() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "Build all other images"
	docker_build_image "nginx" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build_image "coredns" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build_image "gitea" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_start_vault() {
    
	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "start mariadb"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d mariadbvault > /dev/null 2>&1
	log "start vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d vault > /dev/null 2>&1

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_vault_stop() {
	MC_LOGINDENT=$((MC_LOGINDENT+3))
	log "stop vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d vault > /dev/null 2>&1
	log "stop mariadb"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" down -d mariadbvault > /dev/null 2>&1
	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_start_all() {
	MC_LOGINDENT=$((MC_LOGINDENT+3))
	log "start mariadb for vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d mariadbvault > /dev/null 2>&1
	log "start vault"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d vault > /dev/null 2>&1
	log "start mariadb"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d mariadb > /dev/null 2>&1
	log "start nginx"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d nginx > /dev/null 2>&1
	log "start coredns"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d coredns > /dev/null 2>&1
	log "start gitea"
	docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d gitea > /dev/null 2>&1
	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_remove() { 

	local container_name="$1"

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "remove container ""$container_name"""

	# stop container 
	if [ "$(docker ps -f name=${MC_PROJECT}_${container_name}_1 -q)" ]; then log "...Container exist, stop..."; docker stop ${MC_PROJECT}_${container_name}_1 > /dev/null; fi
	# delete container
	if [ "$(docker ps -f name=${MC_PROJECT}_${container_name}_1 -a -q)" ]; then log "...Container exist, delete..."; docker rm ${MC_PROJECT}_${container_name}_1 > /dev/null; fi
	# delete image
	if [ "$(docker images ${MC_PROJECT}/${container_name} -q)" ]; then log "...Image exist, delete..."; docker rmi ${MC_PROJECT}/${container_name} -f > /dev/null; fi
	# delete volume
	if [ "$(docker volume ls -f name=${MC_PROJECT}_${container_name}-data -q)" ]; then log "...Volume exist, delete..."; docker volume rm ${MC_PROJECT}_${container_name}-data > /dev/null; fi

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build_image() {
	
	local container_name="$1"
	local file_name="$2"
	local ret=0

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "(Re-)build image $container_name"
	if [ "$file_name" == "" ]
	then 
		docker-compose build "$container_name" > /dev/null 2>&1
		ret=$?
	else
		log "Use file: $file_name"
		docker-compose -f "$file_name" build "$container_name" > /dev/null 2>&1
		ret=$?
	fi
	if [ "$ret" == "0" ]
	then
		log "success"
	else
		log "failed"
		exit 1
	fi

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_write_roleid() {
	
	local container_name="$1"
	local role_id="$2"

	log "Inject role-id to docker container ${MC_PROJECT}_${container_name}_1"
	docker exec -it ${MC_PROJECT}_${container_name}_1 sh -c 'echo '$role_id' > /home/appuser/data/vault_roleid.txt' > /dev/null 2>&1
    if [ ! $? = 0 ] 
    then 
         log "Failed to write roleid to \"${MC_PROJECT}_${container_name}_1\". Leaving script"
         exit 1
    fi
}

function docker_write_secretid() {
	
	local container_name="$1"
	local secret_id="$2"

	log "Inject secret-id to docker container ${MC_PROJECT}_${container_name}_1"
	docker exec -it ${MC_PROJECT}_${container_name}_1 sh -c 'echo '$secret_id' > /home/appuser/data/vault_secretid.txt'
    if [ ! $? = 0 ]; 
    then 
         log "Failed to write secretid to \"${MC_PROJECT}_${container_name}_1\". Leaving script"
         exit 1
    fi
}

function set_alias() {
	
	local container_name="$1"
	local container_short_name=${arr[$container_name]}
	echo "Create alias ""de$container_short_name=""docker exec -it ${MC_PROJECT}_${container_name}_1 sh"""""
	alias de${container_short_name}='''docker exec -it '${MC_PROJECT}'_'${container_name}'_1 sh'''
	alias dl$container_short_name='''docker logs '${MC_PROJECT}'_'${container_name}'_1'''
}