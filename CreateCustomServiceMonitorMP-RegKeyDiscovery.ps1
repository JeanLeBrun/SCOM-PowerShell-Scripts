#  --- [CreateCustomServiceMonitorMP-RegKeyDiscovery] PowerShell Script  ---
#
# Author(s):        Ryan Irujo
# Inception:        08.18.2013
# Last Modified:    08.18.2013
#
# Description:      This Script provides an automated method of creating Service Monitors in SCOM that are discovered
#                   by using Filtered Registry Key Discoveries. The Script will be parameterized in the very near future. 
#                   Because of the amount of resources that are used on when this script is ran, 
#                   it is probably best that you run it directly on a Management Server where the Operations Console is installed.
#                   Code from both links below was utilized within this script:
#
#
# Changes:          08.18.2013 - [R. Irujo]
#                   - Inception. Script will be parameterized in the near future.
#
#
# Additional Notes: Mind the BACKTICKS throughout the Script! In particular, any XML changes that you may decide to add/remove/change
#                   will require use of them to escape special characters that are commonly used.
#
#
# Syntax:          ./Create-SCOMServiceMonitor <Service_Display_Name> <ServiceName> <CheckStartupType>
#
# Example:         ./Create-SCOMServiceMonitor "VMware Tools" "VMTools" "True"


Clear-Host

# Import Operations Module if it isn't already imported.
If (!(Get-Module OperationsManager)) {
	Import-Module "D:\Program Files\System Center 2012\Operations Manager\Powershell\OperationsManager\OperationsManager.psd1"
	}

$ManagementServer          = "<Management_Server_Name_Goes_Here>"
$ManagementPackID          = "second.test.scom.mp"
$ManagementPackName        = "second.test.scom.mp"
$ManagementPackDisplayName = "Second Test SCOM MP"
$ServiceName               = "VMTools"
$ServiceDisplayName        = "VMware Tools"
$CheckStartupType          = "True"


Write-Host "ManagementServer: "          $ManagementServer
Write-Host "ManagementPackID: "          $ManagementPackID
Write-Host "ManagementPackName: "        $ManagementPackName
Write-Host "ManagementPackDisplayName: " $ManagementPackDisplayName


Write-Host "Connecting to SCOM Management Group"
$MG = New-Object Microsoft.EnterpriseManagement.ManagementGroup($ManagementServer)

Write-Host "Creating new Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore object"
$MPStore = New-Object Microsoft.EnterpriseManagement.Configuration.IO.ManagementPackFileStore

Write-Host "Creating new Microsoft.EnterpriseManagement.Configuration.ManagementPack object"
$MP = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPack($ManagementPackID, $ManagementPackName, (New-Object Version(1, 0, 0)), $MPStore)

Write-Host "Importing Management Pack"
$MG.ImportManagementPack($MP)

Write-Host "Getting Management Pack"
$MP = $MG.GetManagementPacks($ManagementPackID)[0]
	
Write-Host "Setting Display Name"
$MP.DisplayName = $ManagementPackDisplayName

Write-Host "Setting Description"
$MP.Description = "Auto Generated Management Pack via PowerShell"


# Import Operations Module if it isn't already imported.
If (!(Get-Module OperationsManager)) {
	Import-Module "D:\Program Files\System Center 2012\Operations Manager\Powershell\OperationsManager\OperationsManager.psd1"
	}
	

# Getting References to Add to Management Pack
$MPToAdd = Get-SCOMManagementPack | Where-Object {$_.Name -eq "System.Library"}
$MPAlias = "System"


# Adding References to Management Pack
$MPReference = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackReference($MPToAdd)
$MP.References.Add($MPAlias, $MPReference)

Write-Host "New References Added to Management Pack [$($MP.DisplayName)]."


# Create Custom Class
$CustomClass             = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackClass($MP,"CustomServiceMonitorHostsClass","Public")
$CustomClassBase         = ($MG.EntityTypes.GetClasses() | Where-Object {$_.Name -eq "Microsoft.Windows.ComputerRole"})
$CustomClass.Base        = $CustomClassBase
$CustomClass.Hosted      = $true
$CustomClass.DisplayName = "Custom Service Monitor Hosts Class"

Write-Host "$($CustomClass.DisplayName) Added to Management Pack [$($MP.DisplayName)]."


# Create Discoveries - <Discoveries> - XML Portion
$Discovery                = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscovery($MP,"RegKeyDiscovery")
$Discovery.Category       = "Discovery"
$Discovery.DisplayName    = "Discovery by Registry Key"
$Discovery.Description    = "Applies Custom Service Monitoring to a host if it contains a specific Registry Key Entry"


# Create Discovery <Discovery> - XML Portion and Setting 'Target' Value
$DiscoveryTarget          = ($MG.EntityTypes.GetClasses() | Where-Object {$_.Name -eq "Microsoft.Windows.Server.OperatingSystem"}).Base
$Discovery.Target         = $DiscoveryTarget


# Create Discovery Class <DiscoveryClass> - XML Portion and Setting 'TypeID' Value.
$DiscoveryClass           = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDiscoveryClass
$DiscoveryClass.set_TypeID($CustomClass)
$Discovery.DiscoveryClassCollection.Add($DiscoveryClass)


# Create DataSource for Discovery
$DSModuleType             = $MG.GetMonitoringModuleTypes("Microsoft.Windows.FilteredRegistryDiscoveryProvider")[0]
$DSModule                 = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModule($Discovery, "DS")
$DSModule.TypeID          = [Microsoft.EnterpriseManagement.Configuration.ManagementPackDataSourceModuleType]$DSModuleType
$DataSourceConfiguration  = "<ComputerName>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
					          <RegistryAttributeDefinitions>
					            <RegistryAttributeDefinition>
					              <AttributeName>ServiceMonitorRegKeyDiscovery</AttributeName>
					              <Path>SOFTWARE\SCOM\ServiceMonitorRegKeyDiscovery</Path>
					              <PathType>0</PathType>
					              <AttributeType>0</AttributeType>
					            </RegistryAttributeDefinition>
					          </RegistryAttributeDefinitions>
					          <Frequency>300</Frequency>
					          <ClassId>`$MPElement[Name=`"CustomServiceMonitorHostsClass`"]$</ClassId>
					          <InstanceSettings>
					            <Settings>
					              <Setting>
					                <Name>`$MPElement[Name=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Name>
					                <Value>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Value>
					              </Setting>
					              <Setting>
					                <Name>`$MPElement[Name=`"System!System.Entity`"]/DisplayName$</Name>
					                <Value>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/PrincipalName$</Value>
					              </Setting>
					            </Settings>
					          </InstanceSettings>
					          <Expression>
					            <SimpleExpression>
					              <ValueExpression>
					                <XPathQuery Type=`"String`">Values/ServiceMonitorRegKeyDiscovery</XPathQuery>
					              </ValueExpression>
					              <Operator>Equal</Operator>
					              <ValueExpression>
					                <Value Type=`"String`">True</Value>
					              </ValueExpression>
					            </SimpleExpression>
					          </Expression>"
							  
# Adding DataSource and DataSource Configuration to Discovery.
$DSModule.Configuration   = $DataSourceConfiguration
$Discovery.DataSource     = $DSModule

Write-Host "Discovery Configuration was successfully deployed to Management Pack - $($MP.DisplayName)"


# Creating New Service Monitor
$ServiceMonitorType   = $MG.GetUnitMonitorTypes() | Where-Object {$_.Name -eq "Microsoft.Windows.CheckNTServiceStateMonitorType"}
$Monitor              = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitor($MP,($ServiceName+"_"+[Guid]::NewGuid().ToString().Replace("-","")),"Public")


# Setting new New Monitor Up as a Service Monitor and targeting the Hosts of the Group in the MP.
$Monitor.set_DisplayName($ServiceDisplayName)
$Monitor.set_Category("Custom")
$Monitor.set_TypeID($ServiceMonitorType)
$Monitor.set_Target($CustomClass)


# Configure Monitor Alert Settings
$Monitor.AlertSettings = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorAlertSettings
$Monitor.AlertSettings.set_AlertOnState("Error")
$Monitor.AlertSettings.set_AutoResolve($true)
$Monitor.AlertSettings.set_AlertPriority("Normal")
$Monitor.AlertSettings.set_AlertSeverity("Error")
$Monitor.AlertSettings.set_AlertParameter1("`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$")
$Monitor.AlertSettings.AlertMessage


# Configure Alert Settings - Alert Message
$AlertMessage = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackStringResource($MP, "Service.Monitor.Alert.Message")
$AlertMessage.set_DisplayName("The $($ServiceDisplayName) Service has Stopped")
$AlertMessage.set_Description("The $($ServiceDisplayName) Service has Stopped on {0}")
$Monitor.AlertSettings.set_AlertMessage($AlertMessage)


# Configure Health States for the Monitor
$HealthyState = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorOperationalState($Monitor, "Success")
$ErrorState   = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackUnitMonitorOperationalState($Monitor, "Error")
$HealthyState.set_HealthState("Success")
$HealthyState.set_MonitorTypeStateID("Running")
$ErrorState.set_HealthState("Error")
$ErrorState.set_MonitorTypeStateID("NotRunning")
$Monitor.OperationalStateCollection.Add($HealthyState)
$Monitor.OperationalStateCollection.Add($ErrorState)


# Specifying Service Monitoring Configuration
$MonitorConfig = "<ComputerName>`$Target/Host/Property[Type=`"Windows!Microsoft.Windows.Computer`"]/NetworkName$</ComputerName>
                  <ServiceName>$($ServiceName)</ServiceName>
				  <CheckStartupType>$($CheckStartupType)</CheckStartupType>"

$Monitor.set_Configuration($MonitorConfig)


# Specify Parent Monitor by ID
$MonitorCriteria  = New-Object Microsoft.EnterpriseManagement.Configuration.ManagementPackMonitorCriteria("Name='System.Health.AvailabilityState'")
$ParentMonitor    = $MG.GetMonitors($MonitorCriteria)[0]
$Monitor.ParentMonitorID = [Microsoft.EnterpriseManagement.Configuration.ManagementPackElementReference``1[Microsoft.EnterpriseManagement.Configuration.ManagementPackAggregateMonitor]]::op_implicit($ParentMonitor)



Write-Host "$($Monitor.DisplayName) - Service Monitor was successfully deployed to Management Pack - $($MP.DisplayName)"


try {
	$MP.AcceptChanges()
	}
catch [System.Exception]
	{
		echo $_
		exit 2
	}




