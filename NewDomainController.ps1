#Jonathan Bourbonnais - 2019
#This DSC recipe add a domain controller to an existing forest
#This script is provided as-is and is configured in push mode
#It do not create a new forest.
#For further direction on DSC, refer to : https://docs.microsoft.com/en-us/powershell/scripting/dsc/resources/resources?view=powershell-6

#Declare the hostname for the new DC
$server = Read-Host -Prompt "Enter the hostname for your new DC"

#NewDomainController is a function you will be able to call
Configuration NewDomainController
{
    #DECLARE PARAMETER
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        $DomainAdministratorCredential
    )


    #Importe DSC ressources
    #You may need to install them manualy
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xNetworking
    Import-DscResource -ModuleName NetworkingDsc


    node $server
    {

        #Disable DHCP on the network adapter
        NetIPInterface 'DisableDHCP'
        {
            InterfaceAlias = 'Ethernet_lan'
            AddressFamily  = 'IPV4'
            Dhcp           = 'Disabled'
        }

        #Configure static IP adress
        IPAddress 'NewIPV4Address'
        {
            IPAddress      = '10.40.38.110'
            InterfaceAlias = 'Ethernet_lan'
            AddressFamily  = 'IPV4'
            DependsOn = '[NetIPInterface]DisableDHCP'

        }

        #Install ADDS
        WindowsFeature 'InstallADDomainServicesFeature'
        {
            Ensure = 'Present'
            Name   = 'AD-Domain-Services'
        }

        #Install PowerShell RSAT
        WindowsFeature 'RSATADPowerShell'
        {
            Ensure    = 'Present'
            Name      = 'RSAT-AD-PowerShell'
            DependsOn = '[WindowsFeature]InstallADDomainServicesFeature'
        }

        #Install RSAT GUI
        WindowsFeature 'RSATADDSTools'
        {
            Ensure     = 'Present'
            Name       = 'RSAT-ADDS'
            DependsOn  = '[WindowsFeature]RSATADPowershell'
        }

        #Check if the domain exist
        xWaitForADDomain 'WaitForestAvailability'
        {

            DomainName           = 'capitalelab.local'
            DomainUserCredential = $DomainAdministratorCredential
            RetryCount           = 10
            RetryIntervalSec     = 120
            DependsOn            = '[WindowsFeature]RSATADDSTools'
        }

        #Configure ADDS
        xADDomainController 'DomainControllerAllProperties'
        {
            DomainName                     = 'contoso.com'
            DomainAdministratorCredential  = $DomainAdministratorCredential
            SafemodeAdministratorPassword  = $DomainAdministratorCredential
            DatabasePath                   = 'C:\Windows\NTDS'
            LogPath                        = 'C:\Windows\Logs'
            SysvolPath                     = 'C:\Windows\SYSVOL'
            #SiteName                      = ''
            #isGlobalCatalog               = $true
            DependsOn                      = '[xWaitForADDomain]WaitForestAvailability'
        }

    }
}

#Start the DSC Configuration
Start-DscConfiguration -Path C:\Path\To\DSC\Config\File\NewDomainController\ -ComputerName "YOUR-PC-NAME" -Verbose -Debug -Wait -Force

#Run these command if you need to install a DSC module manualy
#Find-Module -Name NetworkingDsc -Repository PSGallery | Install-Module
#Find-Module -Name xActiveDirectory -Repository PSGallery | Install-Module
#Find-Module -Name xNetworking -Repository PSGallery | Install-Module
