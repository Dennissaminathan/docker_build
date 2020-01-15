#!/bin/bash 

VI_CONTAINER="vault"
VI_PROJECT="frickeldave"
VI_VAULTURL="https://localhost"
VI_VAULTPORT="7443"
VI_COMMANDPREFIX='export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"';  

function main() {
    
    parse_input $@
    vault_check_status
    #vault_init
    vault_add_secrets
    cleanup
}

function parse_input() {

	echo "Parse input"

    while [ "$1" != "" ]
    do
        local VI_PARAM=$(echo $1 | awk -F= '{print $1}')
        local VI_VALUE=$(echo $1 | awk -F= '{print $2}')

        case $VI_PARAM in	
            --container) 
                VI_CONTAINER=$VI_VALUE
				echo "   VI_CONTAINER=$VI_CONTAINER"
                ;;
            --project)
                VI_PROJECT=$VI_VALUE
				echo "   VI_PROJECT=$VI_PROJECT"
                ;;
            --vaulttoken)
                VI_TOKEN=$VI_VALUE
				echo "   VI_TOKEN=****************"
                ;;
            --vaulturl)
                VI_VAULTURL=$VI_VALUE
				echo "   VI_VAULTURL=$VI_VAULTURL"
                ;;
            --vaultport)
                VI_VAULTPORT=$VI_VALUE
				echo "   VI_VAULTPORT=$VI_VAULTPORT"
                ;;
            *) # Handles all unknown parameter
                echo "   Ignoring unknown parameter \"$PARAM\""
                ;;
        esac
        shift
    done

    if [ "$VI_TOKEN" == "" ]; then echo "No vault token provided. Exiting script."; exit 1; fi
}

function vault_check_status() {
   
    echo "check status of vault server with address ${VI_VAULTURL}:${VI_VAULTPORT}"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault operator key-status' > /dev/null

    if [ "$?" = "0" ]
    then 
        echo "   success"
    elif [ "$?" = "2" ]
    then 
        echo "   vault is sealed"
        exit 2
    else
        echo "   failed"
        exit 1
    fi
}

function vault_init() {

    ########################################################################
    # Secret store
    ########################################################################

    echo "Create secret store"
    echo "   Check if ""$VI_PROJECT"" kv-store exist"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets list | grep '$VI_PROJECT'' > /dev/null 2>&1
    then
        echo "   kv-store found. Delete it."
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets disable '$VI_PROJECT'' > /dev/null 2>&1
    fi

    echo "   Create new secret store"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets enable -version=2 -path='$VI_PROJECT' kv' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi

    ########################################################################
    # AppRole Authentication
    ########################################################################

    echo "Create AppRole Authentication method"
    echo "   Check if AppRole Authentication method exists"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth list | grep approle_'${VI_PROJECT}'' > /dev/null 2>&1
    then
        echo "   Delete Authentication method AppRole"
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth disable approle_'${VI_PROJECT}'' > /dev/null 2>&1
    fi
    echo "   Create Authentication method AppRole"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth enable -path approle_'${VI_PROJECT}' approle' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi

    ########################################################################
    # Userpass Authentication
    ########################################################################

    echo "Create Userpass Authentication method"
    echo "   Check if Userpass Authentication method exists"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth list | grep userpass_'${VI_PROJECT}'' > /dev/null 2>&1
    then
        echo "   Delete Userpass authentication method"
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth disable userpass_'${VI_PROJECT}'' > /dev/null 2>&1
    fi
    echo "   Create Userpass Authentication method"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth enable -path=userpass_'${VI_PROJECT}' userpass' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi
    
    ########################################################################
    # Admin Policy and user
    ########################################################################
    
    echo "Create admin policy (${VI_PROJECT}_admin)"
    echo 'path "'${VI_PROJECT}'/systems*" {' > /tmp/pol.hcl
    echo '       capabilities = ["create", "read", "update", "delete", "list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${VI_PROJECT}'/*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    echo "   Copy admin policy into docker container"
    docker cp /tmp/pol.hcl "${VI_PROJECT}_${VI_CONTAINER}_1:/tmp/pol.hcl"
    
    echo "   Upload policy to vault"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault policy write '${VI_PROJECT}'_admin /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi
    
    echo "   Create admin user (${VI_PROJECT}_admin)"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write auth/userpass_'${VI_PROJECT}'/users/'${VI_PROJECT}'_admin password=test policies="'${VI_PROJECT}'_admin"' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi

    echo "   User successful created. You can login now with command ""vault login -method=userpass -path=userpass_${VI_PROJECT} username=${VI_PROJECT}_admin password=*****"
}

function vault_add_secrets() {
    
    ########################################################################
    # Init secrets
    ########################################################################

    local projecttimestamp=`date +%Y-%m-%d_%H:%M:%S`
    local secretvalue="created=${projecttimestamp}"
    vault_write_kvsecret "/init" "$secretvalue" "put"

    ########################################################################
    # Gitea secrets
    ########################################################################

    vault_write_apppolicy "gitea"

    secretvalue='GT_MYSQLPASSWORD=gitea2go'
    vault_write_kvsecret "/systems/gitea" "$secretvalue" "put"

    secretvalue='GT_MYSQLADMINPASSWORD=frickeldave2go'
    vault_write_kvsecret "/systems/gitea" "$secretvalue" "patch"

    echo "Create gitea role"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write auth/approle_frickeldave/role/gitea token_policies=frickeldave_systems_gitea token_ttl=1h token_max_ttl=4h' > /dev/null 2>&1
    if [ ! $? = 0 ]; 
    then 
        echo "   failed. Leaving script"
        exit 1
    fi

    local roleid=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault read -format=json auth/approle_frickeldave/role/gitea/role-id | jq -r ".data.role_id"')
    echo "Extracted roleid is: $roleid"

    local secretid=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write -f -format=json auth/approle_frickeldave/role/gitea/secret-id | jq -r ".data.secret_id"')
    echo "Extracted secretid is: $secretid"

    local apptoken=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write -format=json auth/approle_frickeldave/login role_id='${roleid}' secret_id='${secretid}' | jq -r ".auth.client_token"')
    echo "Extracted app token is: $apptoken"
}

function vault_write_kvsecret() {

    local secretpath=$1
    local secretvalue=$2
    local secretmethod=$3

    echo "Create secret in path ${VI_PROJECT}${secretpath}"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault kv '$secretmethod' '${VI_PROJECT}${secretpath}' '${secretvalue}''  > /dev/null 2>&1
    if [ ! $? = 0 ]; 
    then 
        echo "   failed. Leaving script"
        exit 1
    fi
}

function vault_write_apppolicy() {
    
    local appname=$1

    echo "Create app policy (${VI_PROJECT}_systems_${appname})"
    echo 'path "'${VI_PROJECT}'/systems/'${appname}'*" {' > /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    echo "   Copy app policy into docker container"
    docker cp /tmp/pol.hcl "${VI_PROJECT}_${VI_CONTAINER}_1:/tmp/pol.hcl"
    
    echo "   Upload policy to vault"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault policy write '${VI_PROJECT}'_systems_'${appname}' /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        exit 1
    fi
}

function cleanup() {
    
    echo "Cleanup"

    echo "   Delete local policy file"
    rm -f /tmp/pol.hcl
}

main $@