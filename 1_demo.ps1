#region skip ssl
    #Skip ssl stuff...
add-type @" 
    using System.Net; 
    using System.Security.Cryptography.X509Certificates; 
    public class TrustAllCertsPolicy : ICertificatePolicy { 
        public bool CheckValidationResult( 
            ServicePoint srvPoint, X509Certificate certificate, 
            WebRequest request, int certificateProblem) { 
            return true; 
        } 
    } 
"@  


    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    $AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
#endregion

#Build a credential object that will be used to authenticate to vCenter
$cred = Get-Credential

#Create BaseURI based on the vCenter name
$vcenter = "<your-vcenter-here>"
$BaseUri = "https://$vcenter/rest/"

#region Authenticate
    #Authenticate to vCenter
    $SessionUri = $BaseUri + "com/vmware/cis/session"
    $auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($cred.UserName+':'+$Cred.GetNetworkCredential().Password))
    $header = @{
    'Authorization' = "Basic $auth"
    }
    $authResponse = Invoke-RestMethod -Method Post -Headers $header -Uri $SessionUri

    #Create session header to be used in subsequent API calls
    $token = $authResponse.Value
    $sessionheader = @{
        'vmware-api-session-id' = $token
    }
#endregion

#Create URI for working with VMs
$uri = $BaseUri + "vcenter/vm/"

#region List vms

    #Fetch data
    $response = Invoke-RestMethod -Method Get -Headers $sessionheader -Uri $uri
    $response.value

    #Use Powershell techniques for working with the output
    $response.value.name | Sort-Object

#endregion

#region Create VM

    #Generate a random int to use as ID when pulling data from swapi
    $random = Get-Random -Minimum 1 -Maximum 80
    
    #Pull a character from swapi
    $swChar = Invoke-RestMethod -Method Get -Uri "https://swapi.co/api/people/$random/"
    $vmname = $swChar.name

    #Build Body object for creation of VM
    $newVMBody = @{
        "spec"= @{
            "name" = $vmname
            "guest_OS" = "RHEL_7_64"
            "placement" = @{
                "datastore"= "datastore-14"
                "folder"= "group-v9"
                "host" = "host-12"
            }
        }
    } | ConvertTo-Json -Depth 3

    #Send API call for creation of VM
    $createResponse = Invoke-RestMethod -Method Post -Headers $sessionheader -Uri $uri -Body $newVMBody -ContentType "application/json"
    $createResponse.value

    #List VMs to see our newly created VM
    $listResponse = Invoke-RestMethod -Method Get -Headers $sessionheader -Uri $uri
    $listResponse.value.name | Sort-Object

#endregion

#region Update VM

    #Build URI for updating CPU hardware
    $updUri = $uri + ($createResponse.value) + "/hardware/cpu"
    
    #Build body object for updating CPU count of VM
    $updBody = @{
        "spec"= @{
            "cores_per_socket" = 1
            "count" = 8
            "hot_add_enabled"= $false
            "hot_remove_enabled"= $true
        }
    } | ConvertTo-Json -Depth 3

    #Send update
    $updResponse = Invoke-RestMethod -Method Patch -Headers $sessionheader -Uri $updUri -Body $updBody -ContentType "application/json"

#endregion

#region Delete VM

    #Build uri for deletion of VM, include the Id of the VM to delete
    $deleteUri = $uri + $createResponse.value
    $deleteUri

    #Send delete command
    $delResponse = Invoke-RestMethod -Method Delete -Headers $sessionheader -Uri $deleteUri
    
    #Check output -> it's empty
    $delResponse
#endregion