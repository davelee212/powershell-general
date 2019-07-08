Microsoft provided the original version of this script at https://docs.microsoft.com/en-us/windows-server/remote/remote-access/vpn/always-on-vpn/deploy/vpn-deploy-client-vpn-connections

I found the way they provide the script (one "full" copy of it and a section with it split up) a little bit confusing.  HAving copy/pasted it from the docs webpage into Powershell ISE, some of the script gets screwed up and some essentially formatting seems to be interpreted as HTML so the script doesn't run.  Specifically it's the bits that do some substitution of <, > and = in in the file

This has been tested and works :)

As soon as the script runs, the VPN profile is created and, if the machine is off the network, it will connected to the VPN.
