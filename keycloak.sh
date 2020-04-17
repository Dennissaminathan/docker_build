function keycloak_initial_setup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for keycloak availability"
    keycloak_wait_for_startup

    log "create keycloak realm"
    keycloak_create_realm

    log "create keycloak testusers"
    keycloak_create_users

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function keycloak_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check keycloak availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    cnt=0
    while ! docker exec -it ${MC_PROJECT}_keycloak_1 sh -c "${cmd}" > /dev/null 2>&1; do
        ((cnt++))
        log "firststart_finished.flg not available. Wait 15s for slow java junk and try again ..."
        sleep 15s
        if [ $cnt -eq 21 ]
        then
            log "Failed to start keycloak"
            exit 1
        fi
    done

    log "keycloak setup finished. Try to login now to check if keycloak is available."

    local kc_certpwd=$(config_get_value "containers" "keycloak" "CERTPWD")
    local kc_bindaddress=$(config_get_value "containers" "keycloak" "IPADDR")
    local kc_httpsintport=$(config_get_value "containers" "keycloak" "HTTPSINTPORT")
    local kc_adminuser=$(config_get_value "containers" "keycloak" "ADMINUSER")
    local kc_adminpwd=$(config_get_value "containers" "keycloak" "ADMINPWD")

    cmd="cd /home/appuser/app/keycloak/bin;
        ./kcadm.sh config truststore --trustpass ${kc_certpwd} /home/appuser/data/certificates/keycloak_keystore.jks;
        ./kcadm.sh config credentials --server https://${kc_bindaddress}:${kc_httpsintport}/auth --realm master --user ${kc_adminuser} --password ${kc_adminpwd};"

    cnt=0
    while ! docker exec -it ${MC_PROJECT}_keycloak_1 sh -c "${cmd}" > /dev/null 2>&1; do
        ((cnt++))
        log "Keycloak service is not available. Wait 5s and try again ..."
        sleep 5s
        if [ $cnt -eq 21 ]
        then
            log "Failed to start keycloak"
            exit 1
        fi
    done

    log "Keycloak server now available. Lets go."

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function keycloak_create_users() {
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    local user_firstname="firstname"
    local user_lastname="lastname"
    local user_mailusername="mailusername"
    local user_maildomain="mailusername"
    local user_password="password"

    for u in "${users[@]}"
    do
        log "get values for user \"${u}\""
        local user_values=$(config_get_user_values "$u")

        IFS=';' read -ra kvparr <<< "$user_values"    #Convert string to array
        local cnt=0

        for kvp in ${kvparr[@]}
        do
            local param=$(echo $kvp | awk -F= '{print $1}')
            local value=$(echo $kvp | awk -F= '{print $2}')

            case $param in
                FIRSTNAME) 
                    user_firstname=$value
                    ;;
                LASTNAME) 
                    user_lastname=$value
                    ;;
                MAILUSERNAME)
                    if [ "${value}" == '${USERNAME}' ]; then value=$u; fi
                    user_mailusername=$value
                    ;;
                MAILDOMAIN) 
                    if [ "${value}" == '${MAILDOMAIN}' ]; then value=${MC_MAILDOMAIN}; fi
                    user_maildomain=$value
                    ;;
                PASSWORD)
                    if [ "${value}" == '${DEFAULTPASSWORD}' ]; then value=${MC_DEFAULTPASSWORD}; fi 
                    user_password=$value
                    ;;
                *) # Handles all unknown parameter 
                    log "   Ignoring unknown parameter \"$param\""
                    ;;
            esac
            shift
            ((cnt++))
        done
        keycloak_write_user "${u}" "${user_firstname}" "${user_lastname}" "${user_mailusername}" "${user_maildomain}" "${user_password}"
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function keycloak_write_user() {

    local user_username=$1    
    local user_firstname=$2
    local user_lastname=$3
    local user_mailusername=$4
    local user_maildomain=$5
    local user_password=$6

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create user in keycloak"

cat <<EOF > ~/cku.json
        {
        "username": "${user_username}",
        "enabled": true,
        "totp": false,
        "emailVerified": true,
        "firstName": "${user_firstname}",
        "lastName": "${user_lastname}",
        "email": "${user_mailusername}@${user_maildomain}",
        "disableableCredentialTypes": ["password"],
        "requiredActions": [],
        "notBefore": 0,
        "access": {
        "manageGroupMembership": true,
        "view": true,
        "mapRoles": true,
        "impersonate": true,
        "manage": true
        },
        "credentials" : [ 
                        {
                            "value" : "${user_password}", 
                            "type"  : "password",
                            "temporary" : false 
                        } 
                        ],
        "realmRoles" : ["admin","offline_access","uma_authorization"]
    }
EOF

    log "copy json with userinformation into keycloak container"
    docker cp ~/cku.json ${MC_PROJECT}_keycloak_1:/home/appuser/app/cku.json
    
    local kc_certpwd=$(config_get_value "containers" "keycloak" "CERTPWD")
    local kc_bindaddress=$(config_get_value "containers" "keycloak" "IPADDR")
    local kc_httpsintport=$(config_get_value "containers" "keycloak" "HTTPSINTPORT")
    local kc_adminuser=$(config_get_value "containers" "keycloak" "ADMINUSER")
    local kc_adminpwd=$(config_get_value "containers" "keycloak" "ADMINPWD")
    local kc_initrealm=$(config_get_value "containers" "keycloak" "INITREALM")

    log "create user \"${user_username}\" in keycloak with kcadm.sh"
    cmd="cd /home/appuser/app/keycloak/bin;
        ./kcadm.sh config truststore --trustpass ${kc_certpwd} /home/appuser/data/certificates/keycloak_keystore.jks;
        ./kcadm.sh config credentials --server https://${kc_bindaddress}:${kc_httpsintport}/auth --realm master --user ${kc_adminuser} --password ${kc_adminpwd};
        ./kcadm.sh create users -r ${kc_initrealm} -f /home/appuser/app/cku.json"

    docker exec -it ${MC_PROJECT}_keycloak_1 sh -c "${cmd}"  > /dev/null 2>&1
    log "remove json from docker container"
    docker exec -it ${MC_PROJECT}_keycloak_1 sh -c 'rm -f /home/appuser/app/cku.json'
    log "remove local json file"
    rm -f ~/cku.json

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function keycloak_create_realm() {

        MC_LOGINDENT=$((MC_LOGINDENT+3))

        local kc_certpwd=$(config_get_value "containers" "keycloak" "CERTPWD")
        local kc_bindaddress=$(config_get_value "containers" "keycloak" "IPADDR")
        local kc_httpsintport=$(config_get_value "containers" "keycloak" "HTTPSINTPORT")
        local kc_adminuser=$(config_get_value "containers" "keycloak" "ADMINUSER")
        local kc_adminpwd=$(config_get_value "containers" "keycloak" "ADMINPWD")
        local kc_initrealm=$(config_get_value "containers" "keycloak" "INITREALM")

        log "Create realm \"${kc_initrealm}\" in keycloak server"

        cmd="cd /home/appuser/app/keycloak/bin;
        ./kcadm.sh config truststore --trustpass ${kc_certpwd} /home/appuser/data/certificates/keycloak_keystore.jks;
        ./kcadm.sh config credentials --server https://${kc_bindaddress}:${kc_httpsintport}/auth --realm master --user ${kc_adminuser} --password ${kc_adminpwd};
        ./kcadm.sh create realms -s realm=${kc_initrealm} -s enabled=true -o;
        ./add-user-keycloak.sh -r ${kc_initrealm} -u ${kc_adminuser} -p ${kc_adminpwd}"

        docker exec -it ${MC_PROJECT}_keycloak_1 sh -c "${cmd}" > /dev/null 2>&1

        MC_LOGINDENT=$((MC_LOGINDENT-3))
}