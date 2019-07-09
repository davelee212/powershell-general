# Run this script on a machine that has a VPN profile configured correctly.  This script will create two files:
# a) a VPN_Profile.xml file that contains the VPN section of CSP which can be deployed using an MDM (e.g. Intune)
# b) A PowerShell script called VPN_Profile.ps1 that can be run on a users computer and will create the VPN profile 
#     The user must have admin rights for this to work

# This has been successfully tested on:
#   - Windows 10 Pro 1803

# The name of the configured VPN profile on the machine this is being run on
$TemplateName = 'Template VPN Profile'

# The name of the VPN Profile that will be created when the script is run on target computers
# Unique alphanumeric identifier for the profile. The profile name must not include a forward slash (/). 
# If the profile name has a space or other non-alphanumeric character, it must be properly escaped according 
# to the URL encoding standard.
$ProfileName = 'Always On VPN'

# Public or routable IP address or DNS name for the VPN gateway. It can point to the external IP of a 
# gateway or a virtual IP for a server farm. Examples, 208.147.66.130 or vpn.contoso.com.
$Servers = 'remote.mydomain.co.uk'

# Specifies one or more commas separated DNS suffixes. The first in the list is also used as the primary
# connection-specific DNS suffix for the VPN Interface. The entire list will also be added into the SuffixSearchList.
$DnsSuffix = 'corp.mydomain.co.uk'

# Used to indicate the namespace to which the policy applies. When a Name query is issued, the DNS client compares the name 
# in the query to all of the namespaces under DomainNameInformationList to find a match. This parameter can be one of the following types:
#  - FQDN - Fully qualified domain name
#  - Suffix - A domain suffix that will be appended to the shortname query for DNS resolution. To specify a suffix, prepend a period (.) to 
#    the DNS suffix.
$DomainName = '.corp.mydomain.co.uk'

# List of comma-separated DNS Server IP addresses to use for the namespace.
$DNSServers = '192.168.100.10,192.168.100.11'

# This is for the "Trusted Network Detection".  If connected to a network with this DNS Suffix (i.e. supplied to the computer
# via DHCP) then the VPN connection will not connect as it is deemed to be connected to the internal network.  If on a network
# with a different DNS Suffix, it is deemed to be an external network, so the VPN connection will trigger and connect.  I think
# can put multiple comma-delimited values in here if you have trusted networks with different DNS suffixes.

# Comma-separated string to identify the trusted network. VPN does not connect automatically when the user is on their corporate 
# wireless network where protected resources are directly accessible to the device.
# DL: I believe this is the DNS suffix supplied by DHCP for that connection.  I thnk you can supply multiple comma-separated names
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
# This script will only work if the user has admin rights.  It will also not run inside an RDP session because it will not 
# be able to query the user SID.  This situation is only likely to come up in testing so is unlikely to be a problem in practice.
$Script = '$ProfileName = ''' + $ProfileName + '''
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
    # $SidValue to the SID of the user you are logged in and testing with.  You can get the SID of the current user by using 
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
