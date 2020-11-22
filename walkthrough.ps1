# Translated from https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/

$env:SUBSCRIPTION_ID="3a8f9dcb-3662-4322-ae56-e967b95aff7e"
$env:RESOURCE_GROUP="akstest"
$env:CLUSTER_NAME="akstestcluster"
$env:CLUSTER_LOCATION="westus2"

az login
az account set -s "$env:SUBSCRIPTION_ID"

az group delete --name $env:RESOURCE_GROUP --yes

Write-Host "If present, the aktest resource group was deleted. Press <Enter> to create a new 'akstest' resource group." -ForegroundColor Green
Read-Host

az group create --name $env:RESOURCE_GROUP --location $env:CLUSTER_LOCATION

Write-Host "Press <Enter> to create an AKS cluster '$($env:CLUSTER_NAME)' in resource group '$($env:RESOURCE_GROUP)'." -ForegroundColor Green
Read-Host

az aks create -g $env:RESOURCE_GROUP -n $env:CLUSTER_NAME --enable-managed-identity

Write-Host  "AKS cluster created. Press <Enter> to get credentials so kubectl will use the new cluster." -ForegroundColor Green
Read-Host
az aks get-credentials --resource-group $env:RESOURCE_GROUP --name $env:CLUSTER_NAME

$env:IDENTITY_RESOURCE_GROUP="MC_$($env:RESOURCE_GROUP)_$($env:CLUSTER_NAME)_$($env:CLUSTER_LOCATION)"
$env:IDENTITY_NAME="demo"

Write-Host "Identity resource group is: '$($env:IDENTITY_RESOURCE_GROUP)' and Identity name is '$($env:IDENTITY_NAME)'."

Write-Host "Press <Enter> to install aad-pod-identity using helm." -ForegroundColor Green
Read-Host
helm repo add aad-pod-identity https://raw.githubusercontent.com/Azure/aad-pod-identity/master/charts
helm install aad-pod-identity aad-pod-identity/aad-pod-identity -f aad-pod-identity.values.yaml

Write-Host "Press <Enter> to create a managed identity." -ForegroundColor Green
Read-Host
az identity create -g $env:IDENTITY_RESOURCE_GROUP -n $env:IDENTITY_NAME
$env:IDENTITY_CLIENT_ID="$(az identity show -g $env:IDENTITY_RESOURCE_GROUP -n $env:IDENTITY_NAME --query clientId -otsv)"
$env:IDENTITY_RESOURCE_ID="$(az identity show -g $env:IDENTITY_RESOURCE_GROUP -n $env:IDENTITY_NAME --query id -otsv)"

Write-Host "Identity client id is '$($env:IDENTITY_CLIENT_ID)' created in resource group '$($env:IDENTITY_RESOURCE_GROUP)' with identiy name '$($env:IDENTITY_NAME)'."

Write-Host "Will create role assignment in 30 seconds. There is a race condition if we try too soon." -ForegroundColor Yellow
Start-Sleep 30
$env:IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Reader --assignee $($env:IDENTITY_CLIENT_ID) --scope /subscriptions/$($env:SUBSCRIPTION_ID)/resourceGroups/$($env:IDENTITY_RESOURCE_GROUP) --query id -otsv)"

if ($env:IDENTITY_ASSIGNMENT_ID -eq "" -or $env:IDENTITY_ASSIGNMENT_ID -eq $null) {
    Write-Host "Still couldn't get the assignment id. Wait some time and then press <Enter>."
    Read-Host
    $env:IDENTITY_ASSIGNMENT_ID="$(az role assignment create --role Reader --assignee $($env:IDENTITY_CLIENT_ID) --scope /subscriptions/$($env:SUBSCRIPTION_ID)/resourceGroups/$($env:IDENTITY_RESOURCE_GROUP) --query id -otsv)"
}

Write-Host "Identity assignment id is '$($env:IDENTITY_ASSIGNMENT_ID)'."

$cmd = "
apiVersion: `"aadpodidentity.k8s.io/v1`"
kind: AzureIdentity
metadata:
  name: $($env:IDENTITY_NAME)
spec:
  type: 0
  resourceID: $($env:IDENTITY_RESOURCE_ID)
  clientID: $($env:IDENTITY_CLIENT_ID)
"

Write-Host "Press <Enter> to deploy AzureIdentity to the cluster using the following:$([Environment]::NewLine)" -ForegroundColor Green
Write-Host $cmd
Read-Host

$cmd | kubectl apply -f -


$cmd = "
apiVersion: `"aadpodidentity.k8s.io/v1`"
kind: AzureIdentityBinding
metadata:
  name: $($env:IDENTITY_NAME)-binding
spec:
  azureIdentity: $($env:IDENTITY_NAME)
  selector: $($env:IDENTITY_NAME)
"

Write-Host "Press <Enter> to deploy AzureIdentityBinding to the cluster using the following:$([Environment]::NewLine)" -ForegroundColor Green
Write-Host $cmd
Read-Host

$cmd | kubectl apply -f -

$cmd = "
apiVersion: v1
kind: Pod
metadata:
  name: demo
  labels:
    aadpodidbinding: $($env:IDENTITY_NAME)
spec:
  containers:
  - name: demo
    image: mcr.microsoft.com/oss/azure/aad-pod-identity/demo:v1.7.0
    args:
      - --subscriptionid=$($env:SUBSCRIPTION_ID)
      - --clientid=$($env:IDENTITY_CLIENT_ID)
      - --resourcegroup=$($env:IDENTITY_RESOURCE_GROUP)
    env:
      - name: MY_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: MY_POD_NAMESPACE
        valueFrom:
          fieldRef:
            fieldPath: metadata.namespace
      - name: MY_POD_IP
        valueFrom:
          fieldRef:
            fieldPath: status.podIP
  nodeSelector:
    kubernetes.io/os: linux
"

Write-Host "Press <Enter> to deploy identity demo pod to the cluster using the following:$([Environment]::NewLine)" -ForegroundColor Green
Write-Host $cmd
Read-Host

$cmd | kubectl apply -f -

Write-Host "Press <Enter> to show logs for the demo pod." -ForegroundColor Green
Read-Host
kubectl logs demo