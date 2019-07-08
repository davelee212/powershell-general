# Run this script on a machine that has a VPN profile configured correctly.  This script will create two files:
# a) a VPN_Profile.xml file that contains the VPN section of CSP which can be deployed using an MDM (e.g. Intune)
# b) A PowerShell script called VPN_Profile.ps1 that can be run on a users computer and will create the VPN profile 
#     The user must have admin rights for this to work

# This has been successfully tested on:
#   - Windows 10 Pro 1803

# The name of the configured VPN profile on the machine this is being run on
$TemplateName = 'Template VPN'

# The name of the VPN Profile that will be created when the script is run on target computers
$ProfileName = 'Always On VPN'

# The RRAS Server public DNS name
$Servers = 'remote.mydomain.co.uk'

# The DNS Suffix used for resolution of internal servers
$DnsSuffix = 'corp.mydomain.co.uk'

# The domain name, for something??
$DomainName = '.corp.mydomain.co.uk'

# The DNS Server addresses used when connected
$DNSServers = '192.168.100.10,192.168.100.11'

# This is for the "Trusted Network Detection".  If connected to a network with this DNS Suffix (i.e. supplied to the computer
# via DHCP) then the VPN connection will not connect as it is deemed to be connected to the internal network.  If on a network
# with a different DNS Suffix, it is deemed to be an external network, so the VPN connection will trigger and connect
$TrustedNetwork = 'corp.mydomain.co.uk'


$Connection = Get-VpnConnection -Name $TemplateName
if(!$Connection)
{
$Message = "Unable to get $TemplateName connection profile: $_"
Write-Host "$Message"
exit
}
$EAPSettings= $Connection.EapConfigXmlStream.InnerXml

$ProfileXML =
'<VPNProfile>
  <DnsSuffix>' + $DnsSuffix + '</DnsSuffix>
  <NativeProfile>
<Servers>' + $Servers + '</Servers>
<NativeProtocolType>IKEv2</NativeProtocolType>
<Authentication>
  <UserMethod>Eap</UserMethod>
  <Eap>
   <Configuration>
 '+ $EAPSettings + '
   </Configuration>
  </Eap>
</Authentication>
<RoutingPolicyType>SplitTunnel</RoutingPolicyType>
  </NativeProfile>
<AlwaysOn>true</AlwaysOn>
<RememberCredentials>true</RememberCredentials>
<TrustedNetworkDetection>' + $TrustedNetwork + '</TrustedNetworkDetection>
  <DomainNameInformation>
<DomainName>' + $DomainName + '</DomainName>
<DnsServers>' + $DNSServers + '</DnsServers>
</DomainNameInformation>
</VPNProfile>'

$ProfileXML | Out-File -FilePath ($env:USERPROFILE + '\desktop\VPN_Profile.xml')

# This $Script string is where the contents of the PowerShell script are put together before it's written out to a file"
$Script = '# This script will only work if the user has admin rights.  It will also not run inside an RDP session because it will not be able to query the user SID.  This situation is only likely to come up in testing so is unlikely to be a problem in practice.
$ProfileName = ''' + $ProfileName + '''
$ProfileNameEscaped = $ProfileName -replace '' '', ''%20''
$ProfileXML = ''' + $ProfileXML + '''
$ProfileXML = $ProfileXML -replace ''<'', ''&lt;''
$ProfileXML = $ProfileXML -replace ''>'', ''&gt;''
$ProfileXML = $ProfileXML -replace ''"'', ''&quot;''
$nodeCSPURI = ''./Vendor/MSFT/VPNv2''
$namespaceName = ''root\cimv2\mdm\dmmap''
$className = ''MDM_VPNv2_01''

try
{
    # If running this in an RDP session for testing, commend out the 4 lines below this and add in a line to manually set the
    # $SidValue to the SID of the user you're logged in and testing with.  You can get the SID of the current user by using 
    # the command "whoami /user" from a command prompt.
    $username = Gwmi -Class Win32_ComputerSystem | select username
    $objuser = New-Object System.Security.Principal.NTAccount($username.username)
    $sid = $objuser.Translate([System.Security.Principal.SecurityIdentifier])
    $SidValue = $sid.Value
    $Message = "User SID is $SidValue."
    Write-Host "$Message"
}
catch [Exception]
{
    $Message = "Unable to get user SID. User may be logged on over Remote Desktop: $_"
    Write-Host "$Message"
    exit
}

$session = New-CimSession
$options = New-Object Microsoft.Management.Infrastructure.Options.CimOperationOptions
$options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Type", "PolicyPlatform_UserContext", $false)
$options.SetCustomOption("PolicyPlatformContext_PrincipalContext_Id", "$SidValue", $false)

try
{
    $deleteInstances = $session.EnumerateInstances($namespaceName, $className, $options)
    foreach ($deleteInstance in $deleteInstances)
    {
        $InstanceId = $deleteInstance.InstanceID
        if ("$InstanceId" -eq "$ProfileNameEscaped")
        {
            $session.DeleteInstance($namespaceName, $deleteInstance, $options)
            $Message = "Removed $ProfileName profile $InstanceId"
            Write-Host "$Message"
        } else {
            $Message = "Ignoring existing VPN profile $InstanceId"
            Write-Host "$Message"
        }
    }
}
catch [Exception]
{
    $Message = "Unable to remove existing outdated instance(s) of $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

try
{
    $newInstance = New-Object Microsoft.Management.Infrastructure.CimInstance $className, $namespaceName
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ParentID", "$nodeCSPURI", "String", "Key")
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("InstanceID", "$ProfileNameEscaped", "String", "Key")
    $newInstance.CimInstanceProperties.Add($property)
    $property = [Microsoft.Management.Infrastructure.CimProperty]::Create("ProfileXML", "$ProfileXML", "String", "Property")
    $newInstance.CimInstanceProperties.Add($property)
    $session.CreateInstance($namespaceName, $newInstance, $options)
    $Message = "Created $ProfileName profile."

    Write-Host "$Message"
}
catch [Exception]
{
    $Message = "Unable to create $ProfileName profile: $_"
    Write-Host "$Message"
    exit
}

$Message = "Script Complete"
Write-Host "$Message"'

$Script | Out-File -FilePath ($env:USERPROFILE + '\desktop\VPN_Profile.ps1')

$Message = "Successfully created VPN_Profile.xml and VPN_Profile.ps1 on the desktop."
Write-Host "$Message"
