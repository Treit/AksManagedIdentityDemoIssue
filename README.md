# AAD Pod Identity 'Standard Walkthrough' Failure
This repo was created to showcase my failure to get the [Azure Active Directory (AAD) Pod Identity demo](https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/) working and to hopefully get some feedback and/or help on why I cannot get it to work.

## Overview
My end goal is to be able to access Azure Key Vault instances deployed in my Azure subscription using Managed Identity, to remove the need to manually manage certificates, application keys / passwords and similar secrets. Specifically, I want to be able to run as close as possible the same code that I use in non-AKS environments; for instance, using the Key Vault configuration provider middleware in an ASP.NET Core application. This precludes using other techniques such as the Secret Store CSI driver, since that is introducing an entirely different mechanism than would be used in a regular .NET 5 application or a container running in Azure Container Services (where managed identity works without issue.)

## The problem
I have gone through the steps described in the [Standard Walkthrough](https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/) many times, painstakingly and methodically, and I have yet to get it to work.

Ultimately, I have written a PowerShell script that ports the instructions from the above link over, while adding some additional missing steps such as creating the initial resource group and AKS cluster, and then proceeding with each of the specified steps one-by-one.

By starting in a clean Azure subscription and creating all of the resources from scratch, I hope someone with more expertise in this area will be able to try these steps themselves and explain why the final demonstration app fails.

## Steps to reproduce the issue:
1. Clone this repo.
2. Ensure you have an Azure subscription to run this demo in.
3. From a PowerShell terminal window, change to the directory containing this README file.
4. Replace the subscription id in the ./walkthrough.ps1 script with your own subscription id.
4. Execute ./walkthrough.ps1 and follow the prompts. Some of the steps, such as provisioning the AKS cluster, take a few minutes.

## Expected result:
Running `kubectl logs demo` after the script is done shows that the demo app was able to successfully access resources using managed identity.

As described in the [Standard Walkthrough](https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/), we should see some logs that look like this:

```
successfully doARMOperations vm count 1
successfully acquired a token using the MSI, msiEndpoint(http://169.254.169.254/metadata/identity/oauth2/token)
successfully acquired a token, userAssignedID MSI, msiEndpoint(http://169.254.169.254/metadata/identity/oauth2/token) clientID(xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
successfully made GET on instance metadata
```

## Actual result:
Running `kubectl logs demo` shows the following after several minutes:

```
I1122 00:31:32.865022       1 main.go:33] starting demo pod default/demo 10.244.2.6
E1122 00:41:45.796069       1 main.go:73] failed list all vm, error: azure.BearerAuthorizer#WithAuthorization: Failed to refresh the Token for request to https://management.azure.com/subscriptions/3a8f9dcb-3662-4322-ae56-e967b95aff7e/resourceGroups/MC_akstest_akstestcluster_westus2/providers/Microsoft.Compute/virtualMachines?api-version=2019-07-01: StatusCode=404 -- Original Error: adal: Refresh request failed. Status Code = '404'. Response body: getting assigned identities for pod default/demo in ASSIGNED state failed after 20 attempts, retry duration [5]s, error: <nil>. Check MIC pod logs for identity assignment errors
```

Checking the logs of one of the MIC pods shows the following errors:

```
I1122 00:38:29.189439       1 mic.go:1023] processing node aks-nodepool1-40396852-vmss, add [1], del [0], update [0]
I1122 00:38:29.272390       1 cloudprovider.go:210] updating user-assigned identities on aks-nodepool1-40396852-vmss, assign [1], unassign [0]
E1122 00:38:29.382166       1 mic.go:1094] failed to update user-assigned identities on node aks-nodepool1-40396852-vmss (add [1], del [0], update[0]), error: failed to update identities for aks-nodepool1-40396852-vmss in MC_akstest_akstestcluster_westus2, error: compute.VirtualMachineScaleSetsClient#Update: Failure sending request: StatusCode=403 -- Original Error: Code="AuthorizationFailed" Message="The client '659def06-d5bd-4f50-9342-be726950bc4f' with object id '659def06-d5bd-4f50-9342-be726950bc4f' does not have authorization to perform action 'Microsoft.Compute/virtualMachineScaleSets/write' over scope '/subscriptions/3a8f9dcb-3662-4322-ae56-e967b95aff7e/resourceGroups/MC_akstest_akstestcluster_westus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-40396852-vmss' or the scope is invalid. If access was recently granted, please refresh your credentials."
E1122 00:38:29.498228       1 mic.go:1112] failed to apply binding default/demo-binding node aks-nodepool1-40396852-vmss000000 for pod default/demo, error: failed to update identities for aks-nodepool1-40396852-vmss in MC_akstest_akstestcluster_westus2, error: compute.VirtualMachineScaleSetsClient#Update: Failure sending request: StatusCode=403 -- Original Error: Code="AuthorizationFailed" Message="The client '659def06-d5bd-4f50-9342-be726950bc4f' with object id '659def06-d5bd-4f50-9342-be726950bc4f' does not have authorization to perform action 'Microsoft.Compute/virtualMachineScaleSets/write' over scope '/subscriptions/3a8f9dcb-3662-4322-ae56-e967b95aff7e/resourceGroups/MC_akstest_akstestcluster_westus2/providers/Microsoft.Compute/virtualMachineScaleSets/aks-nodepool1-40396852-vmss' or the scope is invalid. If access was recently granted, please refresh your credentials."
I1122 00:38:29.554898       1 mic.go:523] work done: true. Found 1 pods, 1 ids, 1 bindings
```

## Notes
The instructions I followed for this demo are straight-forward, so it's not clear what is missing such that it does not work.

Any help appreciated.

## The script
The full PowerShell script is included alongside this README file, but I present it below as well for convenience.

```
# Translated from https://azure.github.io/aad-pod-identity/docs/demo/standard_walkthrough/

if ($args.Length -eq 0) {
  $env:RESOURCE_GROUP="akstest"
} else {
  $env:RESOURCE_GROUP=$args[0]
}

Write-Host "Using $($env:RESOURCE_GROUP) for the resoruce group name."

$env:SUBSCRIPTION_ID="3a8f9dcb-3662-4322-ae56-e967b95aff7e"
$env:CLUSTER_NAME="akstestcluster"
$env:CLUSTER_LOCATION="westus2"

az login
az account set -s "$env:SUBSCRIPTION_ID"

az group delete --name $env:RESOURCE_GROUP --yes

Write-Host "If present, the '$($env:RESOURCE_GROUP)' resource group was deleted. Press <Enter> to create a new '$($env:RESOURCE_GROUP)' resource group." -ForegroundColor Green
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
  name: $($env:IDENTITY_NAME)
  labels:
    aadpodidbinding: $($env:IDENTITY_NAME)
spec:
  containers:
  - name: $($env:IDENTITY_NAME)
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
```
