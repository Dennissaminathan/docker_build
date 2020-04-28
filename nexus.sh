function nexus_initial_setup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for nexus availability"
    nexus_wait_for_startup

#    log "change nexus initial password"
#    nexus_change_password

    log "create nexus testusers"
    nexus_create_users

    MC_LOGINDENT=$((MC_LOGINDENT-3))

}

function nexus_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check Nexus availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    while ! docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" > /dev/null 2>&1; do
        log "firststart_finished.flg not available. Wait 15s for slow java junk and try again ..."
        sleep 15s
    done

    log "nexus setup finished. Try to login now to check if nexus is available."

    log "Check if nexus is accepting requests"

    cmd="curl -I https://localhost:${NX_INTPORT} --insecure 2>/dev/null | head -n 1 | cut -d$' ' -f2"

    cnt=0
        while ! docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" ; do
	((cnt++))
        log "Nexus service is not available. Wait 30s and try again ..."
        sleep 20s
        if [ $cnt -eq 10 ]
        then
            log "Failed to start Nexus"
            exit 1
        fi
    done


    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function nexus_change_password() {

    cmd="ls /home/appuser/data/firststart.flg"
    while ! docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" > /dev/null 2>&1; do
        echo "firststart_finished.flg not available. Wait 15s for slow java junk and try again ..."
        sleep 10s
    done
   NEXUS_OLD_PWD=$(docker exec -it ${MC_PROJECT}_nexus_1 sh -c  "cat /home/appuser/data/sonatype-work/nexus3/admin.password")


   NEXUS_URL=https://172.6.66.114:${NX_INTPORT}
   NEXUS_NEW_PWD=admin123
   shift 3
   CURL_OPTS="$@"
   SCRIPT_NAME=change_admin_password
   read -r -d '' SCRIPT_JSON << EOF
{
  "name": "${SCRIPT_NAME}",
  "type": "groovy",
  "content": "security.securitySystem.changePassword('admin', args)"
}
EOF

   CHECK_SCRIPT_STATUS=`curl ${CURL_OPTS} -s -o /dev/null -I -w "%{http_code}" -u "admin:${NEXUS_OLD_PWD}" "${NEXUS_URL}/service/siesta/rest/v1/script/${SCRIPT_NAME}"`

   echo $SCRIPT_JSON
#### Below curl posts would reset the admin password but initial password which is created by Nexus is stored at "/home/appuser/data/sonatype-work/nexus3/admin.password" inside container which needs to be changed only in the GUI of nexus using wizard. Initial password is currently unable to reset using below script. i
### If the initial password is reset using GUI then below script can be used to reset the admin password.

   echo $CHECK_SCRIPT_STATUS
   echo $CURL_OPTS

   if [ "${CHECK_SCRIPT_STATUS}" == "404" ];then
    echo "> ${SCRIPT_NAME} is not found (${CHECK_SCRIPT_STATUS})"
    echo "> creating script (${SCRIPT_NAME}) ..."
    curl ${CURL_OPTS} -H "Accept: application/json" -H "Content-Type: application/json" -d "${SCRIPT_JSON}" -u"admin:${NEXUS_OLD_PWD}" "${NEXUS_URL}/service/siesta/rest/v1/script/" --insecure
   elif [ "${CHECK_SCRIPT_STATUS}" == "401" ];then
    echo "> Unauthorized (${CHECK_SCRIPT_STATUS})"
     return
   else
    echo "> ${SCRIPT_NAME} is found (${CHECK_SCRIPT_STATUS})"
    echo "> updating script (${SCRIPT_NAME}) ..."

### Nexus scripts should be uploaded to "/service/siesta/rest/v1/script" location before run it. All configuration scripts should be uploaded first before execution.   
    curl ${CURL_OPTS} -XPUT -H "Accept: application/json" -H "Content-Type: application/json" -d "${SCRIPT_JSON}" -u "admin:${NEXUS_OLD_PWD}" "${NEXUS_URL}/service/siesta/rest/v1/script/${SCRIPT_NAME}" --insecure
  fi


  echo "> updating password ..."
### Uploaded scripts can be executed like below curl post command with credential.

  CHECK_RUN_STATUS=`curl ${CURL_OPTS} -s -o /dev/null -w "%{http_code}" -H "Content-Type: text/plain" -u "admin:${NEXUS_OLD_PWD}" "${NEXUS_URL}/service/siesta/rest/v1/script/${SCRIPT_NAME}/run" -d "${NEXUS_NEW_PWD}" --insecure`

  if [ "${CHECK_RUN_STATUS}" == "200" ];then
    echo "> succeeded!"
  else
    echo "> failed! (${CHECK_RUN_STATUS})"
  fi
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
	    ### Nexus user creation does not accept bulk users in a json file so json should have one user at a time.
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
    #cmd="curl -X POST -u admin:$NEXUS_NEW_PWD "$NEXUS_URL/service/rest/beta/security/users" -H "accept: application/json" -H "Content-Type: application/json" -d @cnu.json –insecure"
    
    #docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd}" > /dev/null 2>&1
    
    #cmd_exec="curl -v -u admin:$NEXUS_NEW_PWD '$NEXUS_URL/service/rest/beta/security/users' –insecure
    #docker exec -it ${MC_PROJECT}_nexus_1 sh -c "${cmd_exec}" > /dev/null 2>&1
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}
