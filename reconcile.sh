#!/bin/bash

if [[ -z "${AAD_APPID}" ]]; then
    echo "AAD_APPID is missing from env var"
    exit 1
fi

if [[ -z "${AAD_APPKEY}" ]]; then
    echo "AAD_APPKEY is missing from env var"
    exit 1
fi

if [[ -z "${AAD_TENANT}" ]]; then
    echo "AAD_TENANT is missing from env var"
    exit 1
fi

if [[ -z "${SUBSCRIPTION}" ]]; then
    echo "SUBSCRIPTION is missing from env var"
    exit 1
fi

if [[ -z "${RESOURCE_GROUP}" ]]; then
    echo "RESOURCE_GROUP is missing from env var"
    exit 1
fi

if [[ -z "${TRAFFIC_MANAGER}" ]]; then
    echo "TRAFFIC_MANAGER is missing from env var"
    exit 1
fi

appId="${AAD_APPID}"
appKey="${AAD_APPKEY}"
tenant="${AAD_TENANT}"
subId="${SUBSCRIPTION}"
resourceGroup="${RESOURCE_GROUP}"
trafficManager="${TRAFFIC_MANAGER}"

az login --service-principal -u "$appId" -p "$appKey" --tenant "$tenant"
az account set --subscription "$subId"

function contains() {
    local n=$#
    local value=${!n}
    for ((i=1;i < $#;i++)) {
        if [ "${!i}" == "${value}" ]; then
            echo "y"
            return 0
        fi
    }
    echo "n"
    return 1
}

containerGroups=( $(az container list -g "$resourceGroup" | jq -r '.[] | "\(.name) \(.tags.trafficGroup) \(.ipAddress.fqdn)"') )
targetList=()

for ((i=0; i<${#containerGroups[*]}; i+=3)); do
    if [ "${containerGroups[i+1]}" == "${trafficManager}" ] && [ "${containerGroups[i+2]}" != "null" ]; then
        targetList+=("${containerGroups[i+2]}")
    fi
done

currentList=( $(az network traffic-manager endpoint list --profile-name "$trafficManager" --resource-group "$resourceGroup" | jq -r '.[].target') )

for i in "${!targetList[@]}"; do
    if [ $(contains "${currentList[@]}" "${targetList[$i]}") == "n" ]; then
        echo "Adding endpoint: ${targetList[$i]}"
        az network traffic-manager endpoint create --name "${targetList[$i]}" --profile-name "$trafficManager" --resource-group "$resourceGroup" --type externalEndpoints --target "${targetList[$i]}" --endpoint-location westus
    fi
done

for i in "${!currentList[@]}"; do
    if [ $(contains "${targetList[@]}" "${currentList[$i]}") == "n" ]; then
        echo "Deleting endpoint: ${currentList[$i]}"
        az network traffic-manager endpoint delete --name "${currentList[$i]}" --profile-name "$trafficManager" --resource-group "$resourceGroup" --type externalEndpoints
    fi
done