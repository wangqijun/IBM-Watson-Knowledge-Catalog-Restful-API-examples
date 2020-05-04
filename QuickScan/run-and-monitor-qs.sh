#!/bin/bash

## Parameters
CP4DURL=https://zen-cpd-zen.apps.cpdv25ga-lb-1.fyre.ibm.com/
USERTOKEN=admin:password
CONNECTIONRID=b1c497ce.8e4c0a48.08g6u34cm.7tj7vcd.ircfju.auotnuu0ph74ltccht7j0
WORKSPACENAME=qijun_test
ROOTASSETS="schema[ibm|sys]"


###################################


###############################
# Step 1: Initiate quick scan
###############################
IMPORTPARAMETERS={}
if [ "x$ROOTASSETS" != "x" ]; then
  IMPORTPARAMETERS="{\"rootAssets\":\"$ROOTASSETS\"}"
fi
QSPAYLOAD="{\"dcRid\":\"${CONNECTIONRID}\",\"projectName\":\"$WORKSPACENAME\",\"importParameters\":$IMPORTPARAMETERS, \"jobSteps\":\"columnAnalysis,dataQualityAnalysis,termAssignment\"}"

echo "-- Running quickscan with $QSPAYLOAD"

TMPFILE=/tmp/qs-monitor.out

### Initiate quick scan REST API
curl -k -u $USERTOKEN -H "Content-Type: application/json" -X POST ${CP4DURL}/ibm/iis/odf/v1/discovery/fastanalyzer --data "$QSPAYLOAD" > $TMPFILE 2> /dev/null

## Get ID from result
DISCOVERYID=$(jq -r .DiscoverOperationId $TMPFILE)
if [ "x$DISCOVERYID" == "xnull" ]; then
  echo "** Running quickscan failed!"
  exit 1
fi

echo "-- Quickscan $DISCOVERYID started"
echo "--"


###############################
# Step 2: Poll result
###############################
STATUS=
while [[ "x$STATUS" != "xFINISHED" && "x$STATUS" != "xERROR" && "x$STATUS" != "xCANCELLED" ]]
do
  echo "-- Wait 5 seconds before querying status of discovery ${DISCOVERYID}"
  sleep 5
  ### Polling status with REST API
  curl -k -u $USERTOKEN -X GET ${CP4DURL}/ibm/iis/odf/v1/discovery/monitor/${DISCOVERYID} > $TMPFILE 2> /dev/null
  STATUS=$(jq -r .overallStatus $TMPFILE)
  echo "-- Found status ${STATUS}"
done

START=$(jq -r .startDate $TMPFILE)
END=$(jq -r .endDate $TMPFILE)

echo "-- Status of discovery ${DISCOVERYID}: ${STATUS}, (start: ${START}, end: ${END})"
