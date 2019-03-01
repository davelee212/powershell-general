# Pass in a text file containing website URLs and it will go and check each site for it's SSL certificate details and expiry info

$timeoutMilliseconds = 10000

$sites = Get-Content -Path 'c:\git\powershell-general\ssl-checker\sitelist.txt'

$returnData = @()

# disable SSL cert checking
[Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

foreach ($site in $sites)
{
#    $url = "https://" + $site.fulladdress
    $url = "https://" + $site
    Write-Host $url
    $req = [Net.HttpWebRequest]::Create($url)
    $req.Timeout = $timeoutMilliseconds
    try 
    {
        $req.GetResponse() | Out-Null

        $certName = $req.ServicePoint.Certificate.GetName()
        #$certPublicKeyString = $req.ServicePoint.Certificate.GetPublicKeyString()
        #$certSerialNumber = $req.ServicePoint.Certificate.GetSerialNumberString()
        #$certThumbprint = $req.ServicePoint.Certificate.GetCertHashString()
        $certIssuer = $req.ServicePoint.Certificate.GetIssuerName()
        $certEffectiveDate = $req.ServicePoint.Certificate.GetEffectiveDateString()
        $expiration = $req.ServicePoint.Certificate.GetExpirationDateString()
        
        write-host "Cert name:  " $certName
        #write-host $certPublicKeyString
        #write-host $certSerialNumber
        #write-host $certThumbprint
        Write-host "Issuer:  " $certIssuer
        write-host "Effective Date:  " $certEffectiveDate
        Write-Host "Expires:  " $expiration

        $certData = New-Object -TypeName PSObject -Property @{
            Address = $url
            Response = "OK"
            CertName = $certName
            Issuer = $certIssuer
            EffectiveDate = $certEffectiveDate
            Expires = $expiration    
        }

        $returnData += $certData


    } 
    catch
    {

        $certData = New-Object -TypeName PSObject -Property @{
            Address = $url
            Response = "ERROR $_"
            CertName = ""
            Issuer = ""
            EffectiveDate = ""
            Expires = ""
        }

        $returnData += $certData

    }

 }

 $returnData | Select Address, Response, CertName, Issuer, EffectiveDate, Expires | Export-CSV -Path 'c:\git\powershell-general\ssl-checker\website-ssl-check-results.csv' -NoType