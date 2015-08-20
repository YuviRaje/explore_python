#!/bin/bash

#
########################################################################
# This utility script deletes workflows and schedules from the appliance.
# The script is not perfect as it only scans for "id" values and
# attempts to delete resource with that id. 
# As workflow has schedule-id while schedule has trigger-id embedded in their 
# resource models, the script will generate 404 errors while attempting to 
# delete resources of the incorrect types.
# The script may also need to be executed multiple times if the data are 
# messed up.
########################################################################
#
TIMESTAMP=`date +%F%H%M%S`
LOGFILE="$TIMESTAMP-cleanup.log"
########################################################################

HOST=${1:-localhost}
LOGIN_URL="https://$HOST:8443/api/login"
CONFIG_WORKFLOW_URL="https://$HOST:8443/api/v1/workflows"
SCHEDULE_URL="https://$HOST:8443/api/v1/schedules"
WORKFLOW="workflows"
SCHEDULE="schedules"


log()
{
    echo -e "$(date) $1" 2>&1 | tee -a $LOGFILE
}


get_token() {
  # get the auth token and trim off extra chars
  TOKEN=$(curl -i -k -X POST -H "Content-Type:application/json" -d '{"username":"admin","password":"admin","domain":"localhost","tenant":"ACME"}' $LOGIN_URL | grep "token" | awk -F: '{print $2}')
  TOKEN=$(echo "${TOKEN%?}" | sed -e 's/^"//'  -e 's/"$//')
}


delete_all(){
  if [ "$1" = "$WORKFLOW" ] 
  then
    url=$CONFIG_WORKFLOW_URL
  else 
    url=$SCHEDULE_URL
  fi

  output=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X GET $url);
  ids=$(echo $output | grep -Po '"id":.*?[^\\]"'| awk -F: '{print $2}' | sed -e 's/^"//'  -e 's/"$//')
  id_array=(${ids// /})
  log "Number of $1 to be deleted - ${#id_array[@]}. Only 1/2 will succeed as the other half are $2"

  for key in "${!id_array[@]}"; do
      id=${id_array[$key]}
      log "Will delete $1 - $id. If this is a $2 instead, a 404 failure will happen"
      #output=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X GET $url/$id)
      output=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X DELETE $url/$id)
      log $output
  done


}


########################################################################
########################################################################
######################### MAIN PROGRAM  ################################
########################################################################
########################################################################

get_token

echo -e "\n\n================================  Begin $TIMESTAMP ================================" 2>&1 | tee -a $LOGFILE


delete_all $WORKFLOW $SCHEDULE
delete_all $SCHEDULE "trigger"


TIMESTAMP2=`date +%F%H%M`

echo -e "\n\n================================  End $TIMESTAMP2 ================================" 2>&1 | tee -a $LOGFILE
