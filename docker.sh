#!/bin/bash


function docker_clean() { 

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

function docker_build_setup() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "Create docker-compose-setupbuild.yml to create initial build containers"
	echo "version: "\'"3.7"\'"" > "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	echo "services:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
  	echo "  alpine:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
    echo "    build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      dockerfile: Dockerfile-alpine-runtime" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      context: ./../docker_alpine" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "    image: ${MC_PROJECT}/alpine:latest" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
  	echo "  build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
    echo "    build:" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      dockerfile: Dockerfile-build-runtime" >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "      context: ." >> "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	echo "    image: ${MC_PROJECT}/build:latest"   >> "${MC_WORKDIR}/docker-compose-setupbuild.yml" 

	log "Build \"alpine\" image"
	docker_build "alpine" "${MC_WORKDIR}/docker-compose-setupbuild.yml"
	log "Build \"build\" image"
	docker_build "build" "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	log "delete temporary files"
	rm -f "${MC_WORKDIR}/docker-compose-setupbuild.yml"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build_all() {

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "Build all other images"
	docker_build "nginx" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "leberkas" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "coredns" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "gitea" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "jdk8" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "jre8" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "jdk11" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "jre11" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "jenkins" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "keycloak" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"
	docker_build "nexus" "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml"

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_build() {
	
	local container_name="$1"
	local file_name="$2"
	local ret=0

	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "(Re-)build image \"$container_name\""

	local folder_name=${container_name}

	if [ "${container_name}" = "jre8" ] || [ "${container_name}" = "jdk8" ] || [ "${container_name}" = "jre11" ] || [ "${container_name}" = "jdk11" ] # Special handling for java
	then
		folder_name="java"
	fi

	log "Create runtime copy of Dockerfile for container image \"$container_name\""
	cp -f "${MC_WORKDIR}/../docker_${folder_name}/Dockerfile-${container_name}" "${MC_WORKDIR}/../docker_${folder_name}/Dockerfile-${container_name}-runtime"

	log "Patch Dockerfile for container image \"$container_name\""
	sed -i -e "s/#MC_PROJECT#/${MC_PROJECT}/g" "${MC_WORKDIR}/../docker_${folder_name}/Dockerfile-${container_name}-runtime"
	
	if [ "${container_name}" == "build" ]
	then
		echo "Patch special variables just used in build image"
		sed -i -e "s/#MC_CONFIGFILE#/${MC_CONFIGFILE}/g" "${MC_WORKDIR}/../docker_${folder_name}/Dockerfile-${container_name}-runtime"
	fi

	log "Use compose-file: $file_name"
	if [ $MC_LOGBUILD -eq 1 ]
	then 
		log "docker-compose output enabled"; docker-compose -f "${file_name}" build "${container_name}"
	else 
		log "docker-compose output disabled"; docker-compose -f "${file_name}" build "${container_name}" > /dev/null 2>&1;
	fi
	ret=$?

	rm -f "${MC_WORKDIR}/../docker_${folder_name}/Dockerfile-${container_name}-runtime"

	if [ "$ret" == "0" ]
	then
		log "success"
	else
		log "failed"
		exit 1
	fi

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_start() {
	
	local container_name=$1
	
	MC_LOGINDENT=$((MC_LOGINDENT+3))

	log "start container \"$container_name\""
	
	if [ $MC_LOGSTART -eq 1 ]
	then
		log "docker-compose output enabled"; 
		docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d $container_name
	else
		log "docker-compose output disabled"; 
		docker-compose -f "${MC_WORKDIR}/docker-compose-${MC_PROJECT}.yml" --project-name "$MC_PROJECT" up -d $container_name > /dev/null 2>&1
	fi 

	MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function docker_write_roleid() {
	
	local container_name="$1"
	local role_id="$2"

	log "Inject role-id to docker container ${MC_PROJECT}_${container_name}_1"
	docker exec -i ${MC_PROJECT}_${container_name}_1 sh -c 'echo '$role_id' > /home/appuser/data/vault_roleid.txt' > /dev/null 2>&1
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
	docker exec -i ${MC_PROJECT}_${container_name}_1 sh -c 'echo '$secret_id' > /home/appuser/data/vault_secretid.txt'
    if [ ! $? = 0 ]; 
    then 
         log "Failed to write secretid to \"${MC_PROJECT}_${container_name}_1\". Leaving script"
         exit 1
    fi
}