#!/bin/bash


container_name=$1
project_name="frickeldave"

echo "Stop existing container"
if [ "$(docker ps -f name=${project_name}_${container_name}_1 -q)" ]; then echo "...Container exist, stop..."; docker stop ${project_name}_${container_name}_1; else echo "...Container does not exist"; fi

echo "Delete existing container"
if [ "$(docker ps -f name=${project_name}_${container_name}_1 -a -q)" ]; then echo "...Container exist, delete..."; docker rm ${project_name}_${container_name}_1; else echo "...Container does not exist"; fi

echo "Delete existing image"
if [ "$(docker images ${project_name}/${container_name} -q)" ]; then echo "...Image exist, delete..."; docker rmi ${project_name}/${container_name} -f; else echo "...Image does not exist"; fi

echo "Delete existing volume"
if [ "$(docker volume ls -f name=${project_name}_${container_name}-data -q)" ]; then echo "...Volume exist, delete..."; docker volume rm ${project_name}_${container_name}-data; else echo "...Volume does not exist"; fi

# export uid and gid for use in docker container, Otherwise you will not get write access to local folder which is mounted in docker container. 
export UID=$(id -u)
export GID=$(id -g)

echo "start containers"
docker-compose --project-name ${project_name} up -d
