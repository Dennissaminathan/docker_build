function nexus_initial_setup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for nexus availability"
    nexus_wait_for_startup

#    log "create nexus realm"
#    nexus_create_realm

    log "create nexus testusers"
    nexus_create_users

    MC_LOGINDENT=$((MC_LOGINDENT-3))

}

function nexus_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check Nexus availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    #while ! docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" > /dev/null 2>&1; do
    #    log "firststart_finished.flg not available. Wait 15s for slow java junk and try again ..."
    #    sleep 15s
    #done

    log "nexus setup finished. Try to login now to check if nexus is available."


    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function nexus_create_users() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    local user_id="firstName"
    local user_firstname="firstName"
    local user_lastname="lastName"
    local user_mailusername="emailAddress"
    local user_maildomain="maildomain"
    local user_password="password"
    local user_status="active"


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
            ##nexus_write_user "${u}" "${user_firstname}" "${user_lastname}" "${user_mailusername}" "${user_maildomain}" "${user_password}"
        done
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
function nexus_write_user() {

    local user_username=$1
    local user_firstname=$2
    local user_lastname=$3
    local user_mailusername=$4
    local user_maildomain=$5
    local user_password=$6

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create user in nexus"

cat <<EOF > ~/cnu.json
        {
        "userId": "${user_username}",
        "firstName": "${user_firstname}",
        "lastName": "${user_lastname}",
        "email": "${user_mailusername}@${user_maildomain}",
        "password": "${user_password}",
        "status": "active",
        "roles": ["nx-admin"]
        }
EOF
    log "Copy user json files to nexus container"

    #docker cp ~/cnu.json ${MC_PROJECT}_nexus_1:/home/appuser/app/cnu.json

    log "Curl user json to nexus for execution"     
    #cmd="curl -X POST -u admin:${NX_CERTPASS} "https://localhost:${INTPORT}/service/rest/beta/security/users" -H "accept: application/json" -H "Content-Type: application/json" -d @cnu.json –insecure"
    
    #docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" > /dev/null 2>&1
    
    #cmd_exec="curl -v -u admin:${NX_ADMINPASS} 'https://localhost:${INTPORT}/service/rest/beta/security/users' –insecure
    #docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd_exec}" > /dev/null 2>&1
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
