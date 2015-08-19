#!/bin/bash

#
########################################################################
# This creates a schdule and then a workflow with that schedule
# The workflow calls
#      com.emc.brs.workflow.action.sample.sleepAction
# The workflow task is updated until 100% completed - about 2 minutes.
#
########################################################################
#
TIMESTAMP=`date +%F%H%M%S`
LOGFILE="schedule-hello-$TIMESTAMP.log"
########################################################################

HOST=${1:-localhost}
LOGIN_URL="https://$HOST:8443/api/login"
CONFIG_WORKFLOW_URL="https://$HOST:8443/api/v1/workflows"
SCHEDULE_URL="https://$HOST:8443/api/v1/schedules"


log()
{
    echo -e "$(date) $1" 2>&1 | tee -a $LOGFILE
}


error_exit()
{
    echo -e "$(date) $1. Exit error code $2" 2>&1 | tee -a $LOGFILE
    echo -e "\n\n================================  End $(date +%F%H%M) ================================" 2>&1 | tee -a $LOGFILE
    exit $2
}


get_token() {
  # get the auth token and trim off extra chars
  TOKEN=$(curl -i -k -X POST -H "Content-Type:application/json" -d '{"username":"admin","password":"admin","domain":"localhost","tenant":"ACME"}' $LOGIN_URL | grep "token" | awk -F: '{print $2}')
  TOKEN=$(echo "${TOKEN%?}" | sed -e 's/^"//'  -e 's/"$//')
}


get_tenant_id() {
 TENANT_ID=$(psql -p 5432 authserver -U auth -c "select id from tenant where displayName='ACME'"|grep -vE "(id|1 row|\-\-+)"|tr -d ' ')
 echo $TENANT_ID
}

#
#
post_schedule() {
  name="SimpleSchedule_$TIMESTAMP"
  timezone=$(date +%Z)
  dayOfWeek=$(date +%a | tr 'a-z' 'A-Z')
  dayOfMonth=$(date +%e | tr -d ' ')
  startHour=$(date +%H | tr -d ' ' )
  start_time=$(date -d "+1 minute" +%FT%T%z)

  #For one-time invocation - can set end_time same as start_time
  #end_time=$start_time
  end_time=$(date -d "+1 hour" +%FT%T%z)

  id=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X POST $SCHEDULE_URL -d \
  '{
    "name": "'$name'",
    "owner": "workflow",
    "attributes": {
        "location": "US"
    },
    "tenantRef": "'$TENANT_ID'",
    "triggers": [
        {
            "type": "MINUTELY",
            "dayOfWeek": "'$dayOfWeek'",
            "dayOfMonth": "'$dayOfMonth'",
            "startHour": "'$startHour'",
            "startMinute": "00",
            "hourlyFrequency": "1",
            "minutelyFrequency": "5",
            "cronExpression": null
        }
    ],
    "enabled": true,
    "priority": "HIGH",
    "timezone": "'$timezone'",
    "scheduleActiveStartDate": "'$start_time'",
    "scheduleActiveEndDate": "'$end_time'",
    "enableHolidayCalendar": false
  }' | grep -Po '"id":.*?[^\\]"' | awk -F: '{print $2}' | head -n 1 | sed -e 's/^"//'  -e 's/"$//')
  echo $id
}


post_workflow(){
  name="SimpleWorklow_$TIMESTAMP"

  id=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X POST $CONFIG_WORKFLOW_URL -d \
  '{
  "name":"'$name'",
  "type":"STATIC",
  "description": "Hello World workflow",
  "tenantRef": "'$TENANT_ID'",
  "controlFlow":"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
     <definitions id=\"definitions\" \n  xmlns=\"http:\/\/www.omg.org\/spec\/BPMN\/20100524\/MODEL\"\n 
        xmlns:activiti=\"http:\/\/activiti.org\/bpmn\"\n  xmlns:xsi=\"http:\/\/www.w3.org\/2001\/XMLSchema-instance\"\n  targetNamespace=\"Examples\">\n\n
       <process id=\"SimplePlan\">\n\n
         <serviceTask id=\"sampleHelloWorldAction\" name=\"Sample HelloWorld Action\" activiti:class=\"com.emc.brs.workflow.action.sample.WriteHelloWorldAction\"\/>\n\n      
         <startEvent id=\"startevent1\" name=\"Start\"\/>\n\n
         <sequenceFlow id=\"flowA\" sourceRef=\"startevent1\" targetRef=\"sampleHelloWorldAction\"\/>\n\n      
         <sequenceFlow id=\"flowB\" sourceRef=\"sampleHelloWorldAction\" targetRef=\"end1\" \/>\n\n      
         <endEvent id=\"end1\" \/>\n\n
       <\/process>\n\n
     <\/definitions>\n",
  "enabled": true,
  "readOnly": true,
  "scheduleRef": "'$1'",
  "schedule": {
    "link": {
        "rel" : "schedules",
        "href":"/schedules/'$1'"
     },
    "id" :"'$1'"
   }
  }' | grep -Po '"id":.*?[^\\]"' | awk -F: '{print $2}' | head -n 1 | sed -e 's/^"//'  -e 's/"$//')
  echo $id
}


get_schedule() {
  output=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X GET $SCHEDULE_URL/$1)
  echo $output
}


get_workflow() {
  output=$(curl -k -i -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -X GET $CONFIG_WORKFLOW_URL/$1)
  echo $output
}


########################################################################
########################################################################
######################### MAIN PROGRAM  ################################
########################################################################
########################################################################

get_token

get_tenant_id

echo -e "\n\n================================  Begin $TIMESTAMP ================================" 2>&1 | tee -a $LOGFILE

schedule_id=`post_schedule`
if [ -z $schedule_id ] 
then
    error_exit "Failed to create schedule" -1
fi
log "Created schedule id=$schedule_id\n" 

sleep 3
output=`get_schedule $schedule_id`
log "Got schedule output:\n $output\n\n"


wf_id=`post_workflow $schedule_id`
if [ -z $wf_id ]
then
    error_exit "Failed to create workflow" -2
fi
log "Created workflow id=$wf_id\n"

sleep 3

output=`get_workflow $wf_id`
log "Got workflow output:\n $output" 


echo -e "\n\n================================  End $(date +%F%H%M) ================================" 2>&1 | tee -a $LOGFILE

exit 0
