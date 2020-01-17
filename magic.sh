#!/bin/sh

MC_PRUNE="false"
MC_CLEAN="false"
MC_BUILD="false"
MC_PROJECT="frickeldave"

if [ $MC_CLEAN == "true" ]
then
    echo "#####################################################################"
    echo "### remove existing images, volumes and container"
    echo "#####################################################################"

    ./docker-rebuild.sh --clean --container="alpine" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="build" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="go" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="nginx" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="coredns" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="mariadb" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="vault" --project="$MC_PROJECT"
    ./docker-rebuild.sh --clean --container="gitea" --project="$MC_PROJECT"
fi

if [ "$MC_PRUNE" == "true" ] 
then
	echo "Prune all images and volumes"
	docker system prune -f -a
fi

if [ "$MC_BUILD" == "true" ] 
then
    echo "#####################################################################"
    echo "### build systems"
    echo "#####################################################################"
    ./docker-rebuild.sh --build --container="alpine" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="build" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="go" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="nginx" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="coredns" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="mariadb" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="vault" --project="$MC_PROJECT"
    ./docker-rebuild.sh --build --container="gitea" --project="$MC_PROJECT"
fi

echo "#####################################################################"
echo "### startup systems"
echo "#####################################################################"
docker-compose --project-name "$MC_PROJECT" up -d

echo "#####################################################################"
echo "### configure vault server"
echo "#####################################################################" 
./vault-init.sh --container=vault --project="$MC_PROJECT"

