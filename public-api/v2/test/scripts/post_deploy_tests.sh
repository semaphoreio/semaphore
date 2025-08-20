#!/bin/bash
if [ "$SEMAPHORE_PIPELINE_2_ARTEFACT_ID" != "" ]; then sleep 3m; fi;

PPL_ID="8a9de6e5-8476-4357-bbaa-c5bcf9fd6459"
echo "Pipeline id is: $PPL_ID"

##Helper functions
parse_response(){
  local RESP=${1//\"/}
  local TEMP=$(echo $RESP | sed "s/.*$2://g")
  local RESULT=$(echo $TEMP | cut -d "," -f 1)
  echo $RESULT
}
uuid_check(){
  PPL_ID_LENGTH=`expr length $1`
  if [ $PPL_ID_LENGTH = 36 ]
  then
          echo "Valid uuid"
  else
          echo "> Uuid is not valid"
          exit 1
  fi
}


##Describe
echo ">>DESCRIBE TEST"
PPL_ID2="5fc0e5dd-f448-4e31-afd0-3dd5897a9db3"
DESC_RESP=`curl -X GET "https://semaphore.semaphoreci.com/api/v1alpha/pipelines/$PPL_ID2" -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU"`
DESC_PPL_ID=`parse_response "$DESC_RESP" "ppl_id"`
echo $DESC_PPL_ID
if [ $PPL_ID2 = $DESC_PPL_ID ]
then
        echo "Describe test passed"
else
        echo "Describe test failed - wrong ppl id"
        exit 1
fi
PROJECT_ID=`parse_response "$DESC_RESP" "project_id"`
echo "project id: $PROJECT_ID"
BRANCH_NAME=`parse_response "$DESC_RESP" "branch_name"`
echo "branch name: $BRANCH_NAME"
STATE=`parse_response "$DESC_RESP" "state"`
echo "state: $STATE"


##Describe - bad pipeline id
echo ">> DESCRIBE - bad ppl id"
DESC_RESP=`curl -X GET "https://semaphore.semaphoreci.com/api/v1alpha/pipelines/123" -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU"`
echo "$DESC_RESP"
if [ "$DESC_RESP" = "Not Found" ]
then
        echo "> Test passed"
else
        echo "> Test failed"
        exit 1
fi


##Terminate
echo ">> TERMINATE TEST"
TERMINATE_RESP=`curl --request PATCH  https://semaphore.semaphoreci.com/api/v1alpha/pipelines/$PPL_ID -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU" --data '{"terminate_request":true}' --header "Content-Type: application/json" --header "Accept: application/json"`
echo $TERMINATE_RESP
if [[ $TERMINATE_RESP = '"Pipeline termination started."' ]]
then
        echo "> Terminate test passed"
else
        echo "> Terminate test failed"
        exit 1
fi


##Partial rebuild
echo ">> PARTIAL REBUILD TEST"
PREBUILD_RESP=`curl -X POST https://semaphore.semaphoreci.com/api/v1alpha/pipelines/$PPL_ID/partial_rebuild -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU" --data '{"request_token":"sdf"}'  --header "Content-Type: application/json" --header "Accept: application/json"`
echo "Partial rebuild response: $PREBUILD_RESP"
if [[ $PREBUILD_RESP = '"Pipelines which passed can not be partial rebuilt."' ]]
then
        echo "> Partial rebuild test failed - ppls which passed can not be partial rebuilt"
        exit 1
else
        true
fi
RESP_PPL_ID=`parse_response "$PREBUILD_RESP" "pipeline_id"`
uuid_check "$RESP_PPL_ID"
echo "> Partial rebuild test passed"


##Partial rebuild - pipeline in state done
echo "PARTIAL REBUILD TEST - pipeline in state done"
if [ "$STATE" = "done" ]
then
        true
else
        echo "> Test failed"
        exit 1
fi
PREBUILD_RESP=`curl -X POST https://semaphore.semaphoreci.com/api/v1alpha/pipelines/$PPL_ID2/partial_rebuild -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU" --data '{"request_token":"sdf"}'  --header "Content-Type: application/json" --header "Accept: application/json"`
echo "Partial rebuild response: $PREBUILD_RESP"
if [[ $PREBUILD_RESP = '"Pipelines which passed can not be partial rebuilt."' ]]
then
        echo "> Test passed"
        true
else
        echo "> Test failed"
        exit 1
fi


##List
echo ">> LIST TEST"
LIST_RESP=`curl -X GET "https://semaphore.semaphoreci.com/api/v1alpha/pipelines?branch_name=$BRANCH_NAME&project_id=$PROJECT_ID" -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU"`
echo "List response: $LIST_RESP"
RESP=(`echo $LIST_RESP | tr -d '[:space:]'`)
check_list_resp(){
    PPL_PROJ_ID=`parse_response "$1" "project_id"`
    if [ $PPL_PROJ_ID = $PROJECT_ID ]
    then
            true
    else
            echo "> Test failed - project ids are not the same"
            exit 1
    fi
    PPL_BRANCH_NAME=`parse_response "$1" "branch_name"`
    if [ $PPL_BRANCH_NAME = $BRANCH_NAME ]
    then
            true
    else
            echo "> Test failed - branch names are not the same"
            exit 1
    fi
    PPL_STATE=`parse_response "$1" "state"`
    if [ $PPL_STATE = "DONE" ]
    then
            true
    else
            echo "> Test failed - state is not done"
            exit 1
    fi
}
PPLS_ARRAY=(`echo $RESP | sed -e 's/},{/\n/g'`)
for PPL in "${PPLS_ARRAY[@]}"
do
    check_list_resp "$PPL"
done
echo "> List test passed"


##Describe topology
echo ">> DESCRIBE TOPOLOGY TEST"
DESC_TOPOLOGY_RESP=`curl -X GET "https://semaphore.semaphoreci.com/api/v1alpha/pipelines/$PPL_ID/describe_topology" -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU"`
echo "Describe topology response: $DESC_TOPOLOGY_RESP"
BLOCKS=(); while read -rd}; do BLOCKS+=("$REPLY"); done <<<"$DESC_TOPOLOGY_RESP}";
for i in "${!BLOCKS[@]}"; do
    TEMP1=${BLOCKS[$i]//\"/}
    TEMP2=${TEMP1//\{/}
    BLOCKS[i]="${TEMP2:1}"
done
check_block(){
  if [[ "${BLOCKS[$1]}" = "$2" ]]
  then
        true
  else
        echo "> Describe topology test failed"
        exit 1
  fi
}
check_block 0 "name:A,jobs:[Nameless 1],dependencies:[]"
check_block 1 "name:B,jobs:[Nameless 1],dependencies:[A,D]"
check_block 2 "name:C,jobs:[Nameless 1],dependencies:[B]"
check_block 3 "name:D,jobs:[Nameless 1],dependencies:[]"
check_block 4 "name:E,jobs:[Nameless 1],dependencies:[B]"
echo "> Describe topology test passed"


##Workflow reschedule
echo ">> RESCHEDULE TEST"
RESCHEDULE_RESP=`curl -X POST https://semaphore.semaphoreci.com/api/v1alpha/plumber-workflows/8e04eeca-d3d0-46a4-843a-836408dd4f8e/reschedule   -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU" -H "x-semaphore-user-id: d71d0493-d5c9-49dc-814f-8b1a50cbd882"  --data request_token=a5fbee0d2939ea4af206696410a5a643c9aee3db`
echo "Reschedule response $RESCHEDULE_RESP"
WF_ID=`parse_response "$RESCHEDULE_RESP" "wf_id"`
echo "wf_id: $WF_ID"
echo "Check wf_id"
uuid_check "$WF_ID"
TEMP=`parse_response "$RESCHEDULE_RESP" "ppl_id"`
PPL_ID=$(echo $TEMP | cut -d "}" -f 1)
echo "ppl_id: $PPL_ID"
echo "Check ppl_id"
uuid_check "$PPL_ID"
echo "> Reschedule test passed"

##Workflow terminate
echo ">> WORKFLOW TERMINATE TEST"
TERMINATE_RESP=` curl -X POST https://semaphore.semaphoreci.com/api/v1alpha/plumber-workflows/8e04eeca-d3d0-46a4-843a-836408dd4f8e/terminate \
  -H "Authorization: Token 4Mtr4KQjT8C-PpWEDXmU" \
  -H "x-semaphore-user-id: d71d0493-d5c9-49dc-814f-8b1a50cbd882" \
  --data client_secret=client_secret`
echo "Terminate response $TERMINATE_RESP"
if [[ $TERMINATE_RESP = '"Termination started for 0 pipelines."' ]]
then
      echo "Workflow terminate test passed"
else
      echo "Workflow terminate test failed"
fi
