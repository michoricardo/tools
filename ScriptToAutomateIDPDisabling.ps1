
#dev
$cosmosEndpoint = "https://sfd152231-db.documents.azure.com:443/"
$cosmosReadOnlyKey = "hCmkVvz3bQLrs8kA7fYfcDSwUFr5piHbaNoBMEbRwQm662Oou8rEK2JGU6d5cVozGvUmSz1GKYAWNSk0mCSDeA=="
$dbName = "idp_dev"

<#
$cosmosEndpoint = "https://sfq154086-db.documents.azure.com:443/"
$cosmosReadOnlyKey = "8uiAWIT48nfEpNezPIZh4QMaH7Oem4JC5DIh2dtAccp9pTmfNMrDcsaBQYeYAd1kZOf54oS2pZF9JVOhbneFYQ=="
$dbName = "idp_qa"
#>
Connect-AzureAD
$script:usersArray=@()
$script:documents = Get-CosmosDocuments -EndPoint $cosmosEndpoint `
        -MasterKey $cosmosReadOnlyKey `
        -DBName $dbName `
        -CollectionName "IdpMainDocumentStorage" -Query @"
              {  
              "query": "SELECT * FROM c WHERE c.documentType = 'IdentityUserDocument' and contains(c.Email,'@epicor.com',false) and not contains(c.Email,'+',false)",
                 
              "parameters": [
              ]  
              } 
"@

function Find-NonEmployees($documents){

foreach($document in $documents.Documents){ #for each of the retrieved documents of the query...
      
      $userActiveProperty = $document.isActive
      $userEmail = $document.email
      $userPart= $userEmail.split("@")[0] #Takes the user part of the email
      
      LookForTenant($document)


      if($owningTenantObject -ne $null){
      $userCurrentTenantName = $owningTenantObject.Documents[0].name #Store the tenant name into a variable 
      }

      $adRecord = Get-AzureADUser -Filter "userPrincipalName  eq '$userEmail' and accountenabled eq true" #If the user has still the AD account enabled
      if($adRecord -eq $null){
         Write-Output "Will search for users with the substring: $($userPart)`n"
         $script:usersArray += $userEmail
         Write-Output "$($document.id)`t$userEmail`t $userCurrentTenantId `t$($userCurrentTenantName)`t Not AD `t Active on idp? $($userActiveProperty)" 
         Get-UsersCreatedByEmployee($usersArray)
         }  
       else{#nothing      
 }
}
}
function Get-UsersCreatedByEmployee($usersArray){
      Write-Output "Checking test users from users that no longer work in Epicor: "
      Write-Output "Array: $($usersArray)"
      Write-Output "Found the following users: "
      foreach($createdUser in $usersArray){
      Write-Output "$($createdUser.Email)"
      
      $createdUsersByEmployee = Get-CosmosDocuments -EndPoint $cosmosEndpoint `
        -MasterKey $cosmosReadOnlyKey `
        -DBName $dbName `
        -CollectionName "IdpMainDocumentStorage" -Query @"
              {  
              "query": "SELECT * FROM c WHERE contains(c.Email,'$userPart+',false)",
                 
              "parameters": [
              ]  
              } 
"@

    foreach($element in $createdUsersByEmployee.Documents){
        Write-Output "$($element.Email)"
        Write-Output "$($element.isActive)"
        Write-Output "$($element.Tenants)"
        }

}
}

function LookForTenant($document){
  $userCurrentTenantId = $document.owningTenantId #Obtain the Tenant id 
      # Now do a query with the tenant id of the current document
      $owningTenantObject = Get-CosmosDocuments -EndPoint $cosmosEndpoint `
        -MasterKey $cosmosReadOnlyKey `
        -DBName $dbName `
        -CollectionName "IdpMainDocumentStorage" -Query @"
              {  
              "query": "SELECT * FROM c WHERE c.id = '$userCurrentTenantId'",
                 
              "parameters": [
              ]  
              } 
"@
}
  
#Main routine
Find-NonEmployees($documents)
