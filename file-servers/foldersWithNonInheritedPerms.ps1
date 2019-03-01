
# Will print out the path to any folder that has permissions on it that are not inherited from the parent

Get-ChildItem e:\london\customers -Recurse | ForEach-Object {

 try { # Get-Acl throws terminating errors, so wrap it in a try/catch block

  $_ | Get-Acl | 
            
   where { $_.AreAccessRulesProtected -or ($_.Access | where { $_.IsInherited -eq $false }) } |

   foreach { Convert-Path $_.Path }
    
 }

 
 catch {
        
  Write-Error $_
    
 }

}
