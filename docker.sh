#!/bin/bash

function docker_remove() { 

	local project_name="$1"
	local container_name="$2"

	log "   remove container ""$container_name"""

	# stop container 
	if [ "$(docker ps -f name=${project_name}_${container_name}_1 -q)" ]; then log "         ...Container exist, stop..."; docker stop ${project_name}_${container_name}_1 > /dev/null; fi
	# delete container
	if [ "$(docker ps -f name=${project_name}_${container_name}_1 -a -q)" ]; then log "         ...Container exist, delete..."; docker rm ${project_name}_${container_name}_1 > /dev/null; fi
	# delete image
	if [ "$(docker images ${project_name}/${container_name} -q)" ]; then log "         ...Image exist, delete..."; docker rmi ${project_name}/${container_name} -f > /dev/null; fi
	# delete volume
	if [ "$(docker volume ls -f name=${project_name}_${container_name}-data -q)" ]; then log "         ...Volume exist, delete..."; docker volume rm ${project_name}_${container_name}-data > /dev/null; fi
}

function docker_build() {
	
	local project_name="$1"
	local container_name="$2"
	local file_name="$3"
	local ret=0

	log "(Re-)build image $container_name"
	if [ "$file_name" == "" ]
	then 
		docker-compose build "$container_name" > /dev/null 2>&1
		ret=$?
	else
		log "   Use file: $file_name"
		docker-compose -f "$file_name" build "$container_name" > /dev/null 2>&1
		ret=$?
	fi
	if [ "$ret" == "0" ]
	then
		log "   success"
	else
		log "   failed"
		exit 1
	fi
}

function docker_write_roleid() {
	
	local project_name="$1"
	local container_name="$2"
	local role_id="$3"

	log "Inject role-id to docker container ${project_name}_${container_name}_1"
	docker exec -it ${project_name}_${container_name}_1 sh -c 'echo '$role_id' > /home/appuser/data/vault_roleid.txt' > /dev/null 2>&1
    if [ ! $? = 0 ] 
    then 
         log "Failed to write roleid to \"${project_name}_${container_name}_1\". Leaving script"
         exit 1
    fi
}

function docker_write_secretid() {
	
	local project_name="$1"
	local container_name="$2"
	local secret_id="$3"

	log "Inject secret-id to docker container ${project_name}_${container_name}_1"
	docker exec -it ${project_name}_${container_name}_1 sh -c 'echo '$secret_id' > /home/appuser/data/vault_secretid.txt'
    if [ ! $? = 0 ]; 
    then 
         log "Failed to write secretid to \"${project_name}_${container_name}_1\". Leaving script"
         exit 1
    fi
}

function set_alias() {
	
	local project_name="$1"
	local container_name="$2"
	local container_short_name=${arr[$container_name]}
	echo "Create alias ""de$container_short_name=""docker exec -it ${project_name}_${container_name}_1 sh"""""
	alias de${container_short_name}='''docker exec -it '${project_name}'_'${container_name}'_1 sh'''
	alias dl$container_short_name='''docker logs '${project_name}'_'${container_name}'_1'''
}