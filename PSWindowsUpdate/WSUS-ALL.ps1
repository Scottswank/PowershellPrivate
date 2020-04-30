Function Update-WUModule
{
	<#
	.SYNOPSIS
		Invoke Get-WUInstall remotely.

	.DESCRIPTION
		Use Invoke-WUInstall to invoke Windows Update install remotly. It Based on TaskScheduler because 
		CreateUpdateDownloader() and CreateUpdateInstaller() methods can't be called from a remote computer - E_ACCESSDENIED.
		
		Note:
		Because we do not have the ability to interact, is recommended use -AcceptAll with WUInstall filters in script block.
	
	.PARAMETER ComputerName
		Specify computer name.

	.PARAMETER PSWUModulePath	
		Destination of PSWindowsUpdate module. Default is C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate
	
	.PARAMETER OnlinePSWUSource
		Link to online source on TechNet Gallery.
		
	.PARAMETER LocalPSWUSource	
		Path to local source on your machine. If you cant use [System.IO.Compression.ZipFile] you must manualy unzip source and set path to it.
			
	.PARAMETER CheckOnly
		Only check current version of PSWindowsUpdate module. Don't update it.
		
	.EXAMPLE
		PS C:\> Update-WUModule

	.EXAMPLE
		PS C:\> Update-WUModule -LocalPSWUSource "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate" -ComputerName PC2,PC3,PC4
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Get-WUInstall
	#>
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]
	param
	(
		[Parameter(ValueFromPipeline=$True,
					ValueFromPipelineByPropertyName=$True)]
		[String[]]$ComputerName = "localhost",
		[String]$PSWUModulePath = "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\PSWindowsUpdate",
		[String]$OnlinePSWUSource = "http://gallery.technet.microsoft.com/2d191bcd-3308-4edd-9de2-88dff796b0bc",
		[String]$SourceFileName = "PSWindowsUpdate.zip",
		[String]$LocalPSWUSource,
		[Switch]$CheckOnly,
		[Switch]$Debuger
	)

	Begin 
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger']
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role
		
		if($LocalPSWUSource -eq "")
		{
			Write-Debug "Prepare temp location"
			$TEMPDentination = [environment]::GetEnvironmentVariable("Temp")
			#$SourceFileName = $OnlinePSWUSource.Substring($OnlinePSWUSource.LastIndexOf("/")+1)
			$ZipedSource = Join-Path -Path $TEMPDentination -ChildPath $SourceFileName
			$TEMPSource = Join-Path -Path $TEMPDentination -ChildPath "PSWindowsUpdate"
			
			Try
			{
				$WebClient = New-Object System.Net.WebClient
				$WebSite = $WebClient.DownloadString($OnlinePSWUSource)
				$WebSite -match "/file/41459/\d*/PSWindowsUpdate.zip" | Out-Null
				
				$OnlinePSWUSourceFile = $OnlinePSWUSource + $matches[0]
				Write-Debug "Download latest PSWindowsUpdate module from website: $OnlinePSWUSourceFile"	
				#Start-BitsTransfer -Source $OnlinePSWUSource -Destination $TEMPDentination
				
				$WebClient.DownloadFile($OnlinePSWUSourceFile,$ZipedSource)
			} #End Try
			catch
			{
				Write-Error "Can't download the latest PSWindowsUpdate module from website: $OnlinePSWUSourceFile" -ErrorAction Stop
			} #End Catch
			
			Try
			{
				if(Test-Path $TEMPSource)
				{
					Write-Debug "Cleanup old PSWindowsUpdate source"
					Remove-Item -Path $TEMPSource -Force -Recurse
				} #End If Test-Path $TEMPSource
				
				Write-Debug "Unzip the latest PSWindowsUpdate module"
				[Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
				[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipedSource,$TEMPDentination)
				$LocalPSWUSource = Join-Path -Path $TEMPDentination -ChildPath "PSWindowsUpdate"
			} #End Try
			catch
			{
				Write-Error "Can't unzip the latest PSWindowsUpdate module" -ErrorAction Stop
			} #End Catch
			
			Write-Debug "Unblock the latest PSWindowsUpdate module"
			Get-ChildItem -Path $LocalPSWUSource | Unblock-File
		} #End If $LocalPSWUSource -eq ""

		$ManifestPath = Join-Path -Path $LocalPSWUSource -ChildPath "PSWindowsUpdate.psd1"
		$TheLatestVersion = (Test-ModuleManifest -Path $ManifestPath).Version
		Write-Verbose "The latest version of PSWindowsUpdate module is $TheLatestVersion"
	}
	
	Process
	{
		ForEach($Computer in $ComputerName)
		{
			if($Computer -eq [environment]::GetEnvironmentVariable("COMPUTERNAME") -or $Computer -eq ".")
			{
				$Computer = "localhost"
			} #End If $Computer -eq [environment]::GetEnvironmentVariable("COMPUTERNAME") -or $Computer -eq "."
			
			if($Computer -eq "localhost")
			{
				$ModuleTest = Get-Module -ListAvailable -Name PSWindowsUpdate
			} #End if $Computer -eq "localhost"
			else
			{
				if(Test-Connection $Computer -Quiet)
				{
					Write-Debug "Check if PSWindowsUpdate module exist on $Computer"
					Try
					{
						$ModuleTest = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-Module -ListAvailable -Name PSWindowsUpdate} -ErrorAction Stop
					} #End Try
					Catch
					{
						Write-Warning "Can't access to machine $Computer. Try use: winrm qc"
						Continue
					} #End Catch
				} #End If Test-Connection $Computer -Quiet
				else
				{
					Write-Warning "Machine $Computer is not responding."
				} #End Else Test-Connection -ComputerName $Computer -Quiet
			} #End Else $Computer -eq "localhost"
			
			If ($pscmdlet.ShouldProcess($Computer,"Update PSWindowsUpdate module from $($ModuleTest.Version) to $TheLatestVersion")) 
			{
				if($Computer -eq "localhost")
				{
					if($ModuleTest.Version -lt $TheLatestVersion)
					{
						if($CheckOnly)
						{
							Write-Verbose "Current version of PSWindowsUpdate module is $($ModuleTest.Version)"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "Copy source files to PSWindowsUpdate module path"
							Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $ModuleTest.ModuleBase -Force
							
							$AfterUpdateVersion = [String]((Get-Module -ListAvailable -Name PSWindowsUpdate).Version)
							Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 
						}#End Else $CheckOnly
					} #End If $ModuleTest.Version -lt $TheLatestVersion
					else
					{
						Write-Verbose "The newest version of PSWindowsUpdate module exist"
					} #ed Else $ModuleTest.Version -lt $TheLatestVersion
				} #End If $Computer -eq "localhost"
				else
				{
					Write-Debug "Connection to $Computer"
					if($ModuleTest -eq $null)
					{
						$PSWUModulePath = $PSWUModulePath -replace ":","$"
						$DestinationPath = "\\$Computer\$PSWUModulePath"

						if($CheckOnly)
						{
							Write-Verbose "PSWindowsUpdate module on machine $Computer doesn't exist"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "PSWindowsUpdate module on machine $Computer doesn't exist. Installing: $DestinationPath"
							Try
							{
								New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
								Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $DestinationPath -Force
								
								$AfterUpdateVersion = [string](Invoke-Command -ComputerName $Computer -ScriptBlock {(Get-Module -ListAvailable -Name PSWindowsUpdate).Version} -ErrorAction Stop)
								Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 								
							} #End Try	
							Catch
							{
								Write-Warning "Can't install PSWindowsUpdate module on machine $Computer."
							} #End Catch
						} #End Else $CheckOnly
					} #End If $ModuleTest -eq $null
					elseif($ModuleTest.Version -lt $TheLatestVersion)
					{
						$PSWUModulePath = $ModuleTest.ModuleBase -replace ":","$"
						$DestinationPath = "\\$Computer\$PSWUModulePath"
						
						if($CheckOnly)
						{
							Write-Verbose "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
						} #End If $CheckOnly
						else
						{
							Write-Verbose "PSWindowsUpdate module version on machine $Computer is ($($ModuleTest.Version)) and it's older then downloaded ($TheLatestVersion). Updating..."							
							Try
							{
								Get-ChildItem -Path $LocalPSWUSource | Copy-Item -Destination $DestinationPath -Force	
								
								$AfterUpdateVersion = [string](Invoke-Command -ComputerName $Computer -ScriptBlock {(Get-Module -ListAvailable -Name PSWindowsUpdate).Version} -ErrorAction Stop)
								Write-Verbose "$($Computer): Update completed: $AfterUpdateVersion" 
							} #End Try
							Catch
							{
								Write-Warning "Can't updated PSWindowsUpdate module on machine $Computer"
							} #End Catch
						} #End Else $CheckOnly
					} #End ElseIf $ModuleTest.Version -lt $TheLatestVersion
					else
					{
						Write-Verbose "Current version of PSWindowsUpdate module on machine $Computer is $($ModuleTest.Version)"
					} #End Else $ModuleTest.Version -lt $TheLatestVersion
				} #End Else $Computer -eq "localhost"
			} #End If $pscmdlet.ShouldProcess($Computer,"Update PSWindowsUpdate module")
		} #End ForEach $Computer in $ComputerName
	}
	
	End 
	{
		if($LocalPSWUSource -eq "")
		{
			Write-Debug "Cleanup PSWindowsUpdate source"
			if(Test-Path $ZipedSource -ErrorAction SilentlyContinue)
			{
				Remove-Item -Path $ZipedSource -Force
			} #End If Test-Path $ZipedSource
			if(Test-Path $TEMPSource -ErrorAction SilentlyContinue)
			{
				Remove-Item -Path $TEMPSource -Force -Recurse
			} #End If Test-Path $TEMPSource	
		}
	}

}

Function Add-WUOfflineSync
{
	<#
	.SYNOPSIS
	    Register offline scaner service.

	.DESCRIPTION
	    Use Add-WUOfflineSync to register Windows Update offline scan file. You may use old wsusscan.cab or wsusscn2.cab from Microsoft Baseline Security Analyzer (MSBA) or System Management Server Inventory Tool for Microsoft Updates (SMS ITMU).
    
	.PARAMETER Path	
		Path to Windows Update offline scan file (wsusscan.cab or wsusscn2.cab).

	.PARAMETER Name	
		Name under which it will be registered Windows Update offline service. Default name is 'Offline Sync Service'.
		
	.EXAMPLE
		Try register Offline Sync Service from file C:\wsusscan.cab at default name.
	
		PS C:\> Add-WUOfflineSync -Path C:\wsusscan.cab

		Confirm
		Are you sure you want to perform this action?
		Performing operation "Register Windows Update offline scan file: C:\wsusscan.cab" on Target "G1".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		ServiceID                            IsManaged IsDefault Name
		---------                            --------- --------- ----
		a8f3b5e6-fb1f-4814-a047-2257d39c2460 False     False     Offline Sync Service

	.EXAMPLE
		Try register Offline Sync Service from file C:\wsusscn2.cab with own name.
		
		PS C:\> Add-WUOfflineSync -Path C:\wsusscn2.cab -Name 'Offline Sync Service2'

		Confirm
		Are you sure you want to perform this action?
		Performing operation "Register Windows Update offline scan file: C:\wsusscn2.cab" on Target "G1".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		ServiceID                            IsManaged IsDefault Name
		---------                            --------- --------- ----
		13df3d8f-78d7-4eb8-bb9c-2a101870d350 False     False     Offline Sync Service2

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
	
	.LINK
		http://msdn.microsoft.com/en-us/library/aa387290(v=vs.85).aspx
		http://support.microsoft.com/kb/926464

	.LINK
        Get-WUServiceManager
        Remove-WUOfflineSync
	#>
    [OutputType('PSWindowsUpdate.WUServiceManager')]
	[CmdletBinding(
        SupportsShouldProcess=$True,
        ConfirmImpact="High"
    )]
    Param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$Path,
		[String]$Name
    )

	Begin
	{
		$DefaultName = "Offline Sync Service" 
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role		
	}
	
    Process
	{
		If(-not (Test-Path $Path))
		{
			Write-Warning "Windows Update offline scan file don't exist in this path: $Path"
			Return
		} #End If -not (Test-Path $Path)
		
		If($Name -eq $null)
		{
			$Name = $DefaultName
		} #End If $Name -eq $null
		
        $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
        Try
        {
            If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Register Windows Update offline scan file: $Path")) 
			{
				$objService = $objServiceManager.AddScanPackageService($Name,$Path,1)
				$objService.PSTypeNames.Clear()
				$objService.PSTypeNames.Add('PSWindowsUpdate.WUServiceManager')
				
			} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Register Windows Update offline scan file: $Path"
        } #End Try
        Catch 
        {
            If($_ -match "HRESULT: 0x80070005")
            {
                Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
            } #End If $_ -match "HRESULT: 0x80070005"
			Else
			{
				Write-Error $_
			} #End Else $_ -match "HRESULT: 0x80070005"
			
            Return
        } #End Catch
		
        Return $objService	
	} #End Process

	End{}
} #In The End :)


Function Add-WUServiceManager 
{
	<#
	.SYNOPSIS
	    Register windows update service manager.

	.DESCRIPTION
	    Use Add-WUServiceManager to register new Windows Update Service Manager.
    
	.PARAMETER ServiceID	
		An identifier for the service to be registered. 
		
		Examples Of ServiceID:
		Windows Update 					9482f4b4-e343-43b6-b170-9a65bc822c77 
		Microsoft Update 				7971f918-a847-4430-9279-4a52d1efe18d 
		Windows Store 					117cab2d-82b1-4b5a-a08c-4d62dbee7782 
		Windows Server Update Service 	3da21691-e39d-4da6-8a4b-b43877bcb1b7 
	
	.PARAMETER AddServiceFlag	
		A combination of AddServiceFlag values. 0x1 - asfAllowPendingRegistration, 0x2 - asfAllowOnlineRegistration, 0x4 - asfRegisterServiceWithAU
	
	.PARAMETER authorizationCabPath	
		The path of the Microsoft signed local cabinet file (.cab) that has the information that is required for a service registration. If empty, the update agent searches for the authorization cabinet file (.cab) during service registration when a network connection is available.
		
	.EXAMPLE
		Try register Microsoft Update Service.
	
		PS H:\> Add-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d"

		Confirm
		Are you sure you want to perform this action?
		Performing the operation "Register Windows Update Service Manager: 7971f918-a847-4430-9279-4a52d1efe18d" on target "MG".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		RegistrationState ServiceID                       IsPendingRegistrationWithAU Service
		----------------- ---------                       --------------------------- -------
                  		3 7971f918-a847-4430-9279-4a...                         False System.__ComObject

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
	
	.LINK
		http://msdn.microsoft.com/en-us/library/aa387290(v=vs.85).aspx
		http://support.microsoft.com/kb/926464

	.LINK
        Get-WUServiceManager
		Remove-WUServiceManager
	#>
    [OutputType('PSWindowsUpdate.WUServiceManager')]
	[CmdletBinding(
        SupportsShouldProcess=$True,
        ConfirmImpact="High"
    )]
    Param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceID,
		[Int]$AddServiceFlag = 2,
		[String]$authorizationCabPath
    )

	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role		
	}
	
    Process
	{
        $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
        Try
        {
            If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Register Windows Update Service Manager: $ServiceID")) 
			{
				
				$objService = $objServiceManager.AddService2($ServiceID,$AddServiceFlag,$authorizationCabPath)
				$objService.PSTypeNames.Clear()
				$objService.PSTypeNames.Add('PSWindowsUpdate.WUServiceManager')
				
			} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Register Windows Update Service Manager: $ServiceID"
        } #End Try
        Catch 
        {
            If($_ -match "HRESULT: 0x80070005")
            {
                Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
            } #End If $_ -match "HRESULT: 0x80070005"
			Else
			{
				Write-Error $_
			} #End Else $_ -match "HRESULT: 0x80070005"
			
            Return
        } #End Catch
		
        Return $objService	
	} #End Process

	End{}
} #In The End :)


Function Get-WUHistory
{
	<#
	.SYNOPSIS
	    Get list of updates history.

	.DESCRIPTION
	    Use function Get-WUHistory to get list of installed updates on current machine. It works similar like Get-Hotfix.
	       
	.PARAMETER ComputerName	
	    Specify the name of the computer to the remote connection.
 	       
	.PARAMETER Debuger	
	    Debug mode.
		
	.EXAMPLE
		Get updates histry list for sets of remote computers.
		
		PS C:\> "G1","G2" | Get-WUHistory

		ComputerName Date                KB        Title
		------------ ----                --        -----
		G1           2011-12-15 13:26:13 KB2607047 Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2607047)
		G1           2011-12-15 13:25:02 KB2553385 Aktualizacja dla programu Microsoft Office 2010 (KB2553385) wersja 64-bitowa
		G1           2011-12-15 13:24:26 KB2618451 Zbiorcza aktualizacja zabezpieczeñ funkcji Killbit formantów ActiveX w sy...
		G1           2011-12-15 13:23:57 KB890830  Narzêdzie Windows do usuwania z³oœliwego oprogramowania dla komputerów z ...
		G1           2011-12-15 13:17:20 KB2589320 Aktualizacja zabezpieczeñ dla programu Microsoft Office 2010 (KB2589320) ...
		G1           2011-12-15 13:16:30 KB2620712 Aktualizacja zabezpieczeñ systemu Windows 7 dla systemów opartych na proc...
		G1           2011-12-15 13:15:52 KB2553374 Aktualizacja zabezpieczeñ dla programu Microsoft Visio 2010 (KB2553374) w...      
		G2           2011-12-17 13:39:08 KB2563227 Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2563227)
		G2           2011-12-17 13:37:51 KB2425227 Aktualizacja zabezpieczeñ systemu Windows 7 dla systemów opartych na proc...
		G2           2011-12-17 13:37:23 KB2572076 Aktualizacja zabezpieczeñ dla programu Microsoft .NET Framework 3.5.1 w s...
		G2           2011-12-17 13:36:53 KB2560656 Aktualizacja zabezpieczeñ systemu Windows 7 dla systemów opartych na proc...
		G2           2011-12-17 13:36:26 KB979482  Aktualizacja zabezpieczeñ dla systemu Windows 7 dla systemów opartych na ...
		G2           2011-12-17 13:36:05 KB2535512 Aktualizacja zabezpieczeñ systemu Windows 7 dla systemów opartych na proc...
		G2           2011-12-17 13:35:41 KB2387530 Aktualizacja dla systemu Windows 7 dla systemów opartych na procesorach x...
	
	.EXAMPLE  
		Get information about specific installed updates.
	
		PS C:\> $WUHistory = Get-WUHistory
		PS C:\> $WUHistory | Where-Object {$_.Title -match "KB2607047"} | Select-Object *


		KB                  : KB2607047
		ComputerName        : G1
		Operation           : 1
		ResultCode          : 1
		HResult             : -2145116140
		Date                : 2011-12-15 13:26:13
		UpdateIdentity      : System.__ComObject
		Title               : Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2607047)
		Description         : Zainstalowanie tej aktualizacji umo¿liwia rozwi¹zanie problemów w systemie Windows. Aby uzyskaæ p
		                      e³n¹ listê problemów, które zosta³y uwzglêdnione w tej aktualizacji, nale¿y zapoznaæ siê z odpowi
		                      ednim artyku³em z bazy wiedzy Microsoft Knowledge Base w celu uzyskania dodatkowych informacji. P
		                      o zainstalowaniu tego elementu mo¿e byæ konieczne ponowne uruchomienie komputera.
		UnmappedResultCode  : 0
		ClientApplicationID : AutomaticUpdates
		ServerSelection     : 1
		ServiceID           :
		UninstallationSteps : System.__ComObject
		UninstallationNotes : Tê aktualizacjê oprogramowania mo¿na usun¹æ, wybieraj¹c opcjê Wyœwietl zainstalowane aktualizacje
		                       w aplecie Programy i funkcje w Panelu sterowania.
		SupportUrl          : http://support.microsoft.com
		Categories          : System.__ComObject

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
		Get-WUList
		
	#>
	[OutputType('PSWindowsUpdate.WUHistory')]
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="Low"
	)]
	Param
	(
		#Mode options
		[Switch]$Debuger,
		[parameter(ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true)]
		[String[]]$ComputerName	
	)

	Begin
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger'] 

		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role		
	}
	
	Process
	{
		#region STAGE 0
		Write-Debug "STAGE 0: Prepare environment"
		######################################
		# Start STAGE 0: Prepare environment #
		######################################
		
		Write-Debug "Check if ComputerName in set"
		If($ComputerName -eq $null)
		{
			Write-Debug "Set ComputerName to localhost"
			[String[]]$ComputerName = $env:COMPUTERNAME
		} #End If $ComputerName -eq $null

		####################################
		# End STAGE 0: Prepare environment #
		####################################
		#endregion
		
		$UpdateCollection = @()
		Foreach($Computer in $ComputerName)
		{
			If(Test-Connection -ComputerName $Computer -Quiet)
			{
				#region STAGE 1
				Write-Debug "STAGE 1: Get history list"
				###################################
				# Start STAGE 1: Get history list #
				###################################
		
				If ($pscmdlet.ShouldProcess($Computer,"Get updates history")) 
				{
					Write-Verbose "Get updates history for $Computer"
					If($Computer -eq $env:COMPUTERNAME)
					{
						Write-Debug "Create Microsoft.Update.Session object for $Computer"
						$objSession = New-Object -ComObject "Microsoft.Update.Session" #Support local instance only
					} #End If $Computer -eq $env:COMPUTERNAME
					Else
					{
						Write-Debug "Create Microsoft.Update.Session object for $Computer"
						$objSession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Computer))
					} #End Else $Computer -eq $env:COMPUTERNAME

					Write-Debug "Create Microsoft.Update.Session.Searcher object for $Computer"
					$objSearcher = $objSession.CreateUpdateSearcher()
					$TotalHistoryCount = $objSearcher.GetTotalHistoryCount()

					If($TotalHistoryCount -gt 0)
					{
						$objHistory = $objSearcher.QueryHistory(0, $TotalHistoryCount)
						$NumberOfUpdate = 1
						Foreach($obj in $objHistory)
						{
							Write-Progress -Activity "Get update histry for $Computer" -Status "[$NumberOfUpdate/$TotalHistoryCount] $($obj.Title)" -PercentComplete ([int]($NumberOfUpdate/$TotalHistoryCount * 100))

							Write-Debug "Get update histry: $($obj.Title)"
							Write-Debug "Convert KBArticleIDs"
							$matches = $null
							$obj.Title -match "KB(\d+)" | Out-Null
							
							If($matches -eq $null)
							{
								Add-Member -InputObject $obj -MemberType NoteProperty -Name KB -Value ""
							} #End If $matches -eq $null
							Else
							{							
								Add-Member -InputObject $obj -MemberType NoteProperty -Name KB -Value ($matches[0])
							} #End Else $matches -eq $null
							
							Add-Member -InputObject $obj -MemberType NoteProperty -Name ComputerName -Value $Computer
							
							$obj.PSTypeNames.Clear()
							$obj.PSTypeNames.Add('PSWindowsUpdate.WUHistory')
						
							$UpdateCollection += $obj
							$NumberOfUpdate++
						} #End Foreach $obj in $objHistory
						Write-Progress -Activity "Get update histry for $Computer" -Status "Completed" -Completed
					} #End If $TotalHistoryCount -gt 0
					Else
					{
						Write-Warning "Probably your history was cleared. Alternative please run 'Get-WUList -IsInstalled'"
					} #End Else $TotalHistoryCount -gt 0
				} #End If $pscmdlet.ShouldProcess($Computer,"Get updates history")
				
				################################
				# End PASS 1: Get history list #
				################################
				#endregion
				
			} #End If Test-Connection -ComputerName $Computer -Quiet
		} #End Foreach $Computer in $ComputerName	
		
		Return $UpdateCollection
	} #End Process

	End{}	
} #In The End :)

Function Get-WUInstall
{
	<#
	.SYNOPSIS
		Download and install updates.

	.DESCRIPTION
		Use Get-WUInstall to get list of available updates, next download and install it. 
		There are two types of filtering update: Pre search criteria, Post search criteria.
		- Pre search works on server side, like example: ( IsInstalled = 0 and IsHidden = 0 and CategoryIds contains '0fa1201d-4330-4fa8-8ae9-b877473b6441' )
		- Post search work on client side after downloading the pre-filtered list of updates, like example $KBArticleID -match $Update.KBArticleIDs
		
		Update occurs in four stages: 1. Search for updates, 2. Choose updates, 3. Download updates, 4. Install updates.
		
	.PARAMETER UpdateType
		Pre search criteria. Finds updates of a specific type, such as 'Driver' and 'Software'. Default value contains all updates.

	.PARAMETER UpdateID
		Pre search criteria. Finds updates of a specific UUID (or sets of UUIDs), such as '12345678-9abc-def0-1234-56789abcdef0'.

	.PARAMETER RevisionNumber
		Pre search criteria. Finds updates of a specific RevisionNumber, such as '100'. This criterion must be combined with the UpdateID param.

	.PARAMETER CategoryIDs
		Pre search criteria. Finds updates that belong to a specified category (or sets of UUIDs), such as '0fa1201d-4330-4fa8-8ae9-b877473b6441'.

	.PARAMETER IsInstalled
		Pre search criteria. Finds updates that are installed on the destination computer.

	.PARAMETER IsHidden
		Pre search criteria. Finds updates that are marked as hidden on the destination computer. Default search criteria is only not hidden upadates.
	
	.PARAMETER WithHidden
		Pre search criteria. Finds updates that are both hidden and not on the destination computer. Overwrite IsHidden param. Default search criteria is only not hidden upadates.
		
	.PARAMETER Criteria
		Pre search criteria. Set own string that specifies the search criteria.

	.PARAMETER ShowSearchCriteria
		Show choosen search criteria. Only works for pre search criteria.
		
	.PARAMETER RootCategories
		Post search criteria. Finds updates that contain a specified root category name 'Critical Updates', 'Definition Updates', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades', 'Microsoft'

	.PARAMETER Category
		Post search criteria. Finds updates that contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER KBArticleID
		Post search criteria. Finds updates that contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER Title
		Post search criteria. Finds updates that match part of title, such as ''

	.PARAMETER Severity
		Post search criteria. Finds updates that match part of severity, such as 'Important', 'Critical', 'Moderate', etc...

	.PARAMETER NotCategory
		Post search criteria. Finds updates that not contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER NotKBArticleID
		Post search criteria. Finds updates that not contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER NotTitle
		Post search criteria. Finds updates that not match part of title.
	
	.PARAMETER NotSeverity
		Post search criteria. Finds updates that not match part of severity.

	.PARAMETER MaxSize
		Post search criteria. Finds updates that have MaxDownloadSize less or equal. Size is in Bytes.

	.PARAMETER MinSize
		Post search criteria. Finds updates that have MaxDownloadSize greater or equal. Size is in Bytes.
				
	.PARAMETER IgnoreUserInput
		Post search criteria. Finds updates that the installation or uninstallation of an update can't prompt for user input.
	
	.PARAMETER IgnoreRebootRequired
		Post search criteria. Finds updates that specifies the restart behavior that not occurs when you install or uninstall the update.
	
	.PARAMETER ServiceID
		Set ServiceIS to change the default source of Windows Updates. It overwrite ServerSelection parameter value.

	.PARAMETER WindowsUpdate
		Set Windows Update Server as source. Default update config are taken from computer policy.
		
	.PARAMETER MicrosoftUpdate
		Set Microsoft Update Server as source. Default update config are taken from computer policy.
		
	.PARAMETER ListOnly
		Show list of updates only without downloading and installing. Works similar like Get-WUList.
	
	.PARAMETER DownloadOnly
		Show list and download approved updates but do not install it. 
	
	.PARAMETER AcceptAll
		Do not ask for confirmation updates. Install all available updates.
	
	.PARAMETER AutoReboot
		Do not ask for rebbot if it needed.
	
	.PARAMETER IgnoreReboot
		Do not ask for reboot if it needed, but do not reboot automaticaly. 
	
	.PARAMETER AutoSelectOnly  
		Install only the updates that have status AutoSelectOnWebsites on true.

	.PARAMETER Debuger	
	    Debug mode.

	.EXAMPLE
		Get info about updates that are not require user interaction to install.
	
		PS C:\> Get-WUInstall -MicrosoftUpdate -IgnoreUserInput -WhatIf -Verbose
		VERBOSE: Connecting to Microsoft Update server. Please wait...
		VERBOSE: Found [39] Updates in pre search criteria
		VERBOSE: Found [5] Updates in post search criteria to Download
		What if: Performing operation "Aktualizacja firmy Microsoft z ekranem wybierania przeglądarki dla użytkowników systemu W
		indows 7 dla systemów opartych na procesorach x64 w Europejskim Obszarze Gospodarczym (KB976002)[1 MB]?" on Target "KOMP
		UTER".
		What if: Performing operation "Aktualizacja dla systemu Windows 7 dla systemów opartych na procesorach x64 (KB971033)[1
		MB]?" on Target "KOMPUTER".
		What if: Performing operation "Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)[1 MB]?" on Ta
		rget "KOMPUTER".
		What if: Performing operation "Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla systemów opart
		ych na procesorach x64 (KB982670)[1 MB]?" on Target "KOMPUTER".
		What if: Performing operation "Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z procesorem x64 -
		 grudzień 2011 (KB890830)[1 MB]?" on Target "KOMPUTER".

		X Status     KB          Size Title
		- ------     --          ---- -----
		2 Rejected   KB890830    1 MB Aktualizacja firmy Microsoft z ekranem wybierania przeglądarki dla użytkowników system...
		2 Rejected   KB890830    1 MB Aktualizacja dla systemu Windows 7 dla systemów opartych na procesorach x64 (KB971033)
		2 Rejected   KB890830    1 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)
		2 Rejected   KB890830    1 MB Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla systemów op...
		2 Rejected   KB890830    1 MB Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z procesorem x6...
		VERBOSE: Accept [0] Updates to Download
	
	.EXAMPLE
		Get updates from specific source with title contains ".NET Framework 4". Everything automatic accept and install.
	
		PS C:\> Get-WUInstall -ServiceID 9482f4b4-e343-43b6-b170-9a65bc822c77 -Title ".NET Framework 4" -AcceptAll

		X Status     KB          Size Title
		- ------     --          ---- -----
		2 Accepted   KB982670   48 MB Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla systemów op...
		3 Downloaded KB982670   48 MB Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla systemów op...
		4 Installed  KB982670   48 MB Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla systemów op...

	.EXAMPLE
		Get updates with specyfic KBArticleID. Check if type are "Software" and automatic install all.
		
		PS C:\> $KBList = "KB890830","KB2533552","KB2539636"
		PS C:\> Get-WUInstall -Type "Software" -KBArticleID $KBList -AcceptAll

		X Status     KB          Size Title
		- ------     --          ---- -----
		2 Accepted   KB2533552   9 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)
		2 Accepted   KB2539636   4 MB Aktualizacja zabezpieczeń dla programu Microsoft .NET Framework 4 w systemach Windows ...
		2 Accepted   KB890830    1 MB Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z procesorem x6...
		3 Downloaded KB2533552   9 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)
		3 Downloaded KB2539636   4 MB Aktualizacja zabezpieczeń dla programu Microsoft .NET Framework 4 w systemach Windows ...
		3 Downloaded KB890830    1 MB Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z procesorem x6...	
		4 Installed  KB2533552   9 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)
		4 Installed  KB2539636   4 MB Aktualizacja zabezpieczeń dla programu Microsoft .NET Framework 4 w systemach Windows ...
		4 Installed  KB890830    1 MB Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z procesorem x6...
	
	.EXAMPLE
		Get list of updates without language packs and updatets that's not hidden.

		PS C:\> Get-WUInstall -NotCategory "Language packs" -ListOnly

		X Status KB          Size Title
		- ------ --          ---- -----
		1 ------ KB2640148   8 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2640148)
		1 ------ KB2600217  32 MB Aktualizacja dla programu Microsoft .NET Framework 4 w systemach Windows XP, Se...
		1 ------ KB2679255   6 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2679255)
		1 ------ KB915597    3 MB Definition Update for Windows Defender - KB915597 (Definition 1.125.146.0)
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
		http://msdn.microsoft.com/en-us/library/windows/desktop/aa386526(v=vs.85).aspx
		http://msdn.microsoft.com/en-us/library/windows/desktop/aa386099(v=vs.85).aspx
		http://msdn.microsoft.com/en-us/library/ff357803(VS.85).aspx

	.LINK
		Get-WUServiceManager
		Get-WUList
	#>
	[OutputType('PSWindowsUpdate.WUInstall')]
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]	
	Param
	(
		#Pre search criteria
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[ValidateSet("Driver", "Software")]
		[String]$UpdateType="",
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$UpdateID,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Int]$RevisionNumber,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$CategoryIDs,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Switch]$IsInstalled,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Switch]$IsHidden,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Switch]$WithHidden,
		[String]$Criteria,
		[Switch]$ShowSearchCriteria,
		
		#Post search criteria
        [ValidateSet('Critical Updates', 'Definition Updates', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades', 'Microsoft')]
        [String[]]$RootCategories,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$Category="",
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$KBArticleID,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String]$Title,
		[parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Critical", "Important", "Moderate", "Low", "Unspecified", "")]
		[String[]]$Severity,
		
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$NotCategory="",
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String[]]$NotKBArticleID,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[String]$NotTitle,
		[parameter(ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("Critical", "Important", "Moderate", "Low", "Unspecified", "")]
		[String[]]$NotSeverity,
        [Int]$MaxSize,
        [Int]$MinSize,
        		
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Alias("Silent")]
		[Switch]$IgnoreUserInput,
		[parameter(ValueFromPipelineByPropertyName=$true)]
		[Switch]$IgnoreRebootRequired,
		
		#Connection options
		[String]$ServiceID,
		[Switch]$WindowsUpdate,
		[Switch]$MicrosoftUpdate,
		
		#Mode options
		[Switch]$ListOnly,
		[Switch]$DownloadOnly,
		[Alias("All")]
		[Switch]$AcceptAll,
		[Switch]$AutoReboot,
		[Switch]$IgnoreReboot,
		[Switch]$AutoSelectOnly,
		[Switch]$Debuger
	)

	Begin
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger']
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role
	}

	Process
	{
		#region	STAGE 0	
		######################################
		# Start STAGE 0: Prepare environment #
		######################################
		
		Write-Debug "STAGE 0: Prepare environment"
		If($IsInstalled)
		{
			$ListOnly = $true
			Write-Debug "Change to ListOnly mode"
		} #End If $IsInstalled

		Write-Debug "Check reboot status only for local instance"
		Try
		{
			$objSystemInfo = New-Object -ComObject "Microsoft.Update.SystemInfo"	
			If($objSystemInfo.RebootRequired)
			{
				Write-Warning "Reboot is required to continue"
				If($AutoReboot)
				{
					Restart-Computer -Force
				} #End If $AutoReboot

				If(!$ListOnly)
				{
					Return
				} #End If !$ListOnly	
				
			} #End If $objSystemInfo.RebootRequired
		} #End Try
		Catch
		{
			Write-Warning "Support local instance only, Continue..."
		} #End Catch
		
		Write-Debug "Set number of stage"
		If($ListOnly)
		{
			$NumberOfStage = 2
		} #End $ListOnly
		ElseIf($DownloadOnly)
		{
			$NumberOfStage = 3
		} #End Else $ListOnly If $DownloadOnly
		Else
		{
			$NumberOfStage = 4
		} #End Else $DownloadOnly
		
		####################################			
		# End STAGE 0: Prepare environment #
		####################################
		#endregion
		
		#region	STAGE 1
		###################################
		# Start STAGE 1: Get updates list #
		###################################			
		
		Write-Debug "STAGE 1: Get updates list"
		Write-Debug "Create Microsoft.Update.ServiceManager object"
		$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager" 
		
		Write-Debug "Create Microsoft.Update.Session object"
		$objSession = New-Object -ComObject "Microsoft.Update.Session" 
		
		Write-Debug "Create Microsoft.Update.Session.Searcher object"
		$objSearcher = $objSession.CreateUpdateSearcher()

		If($WindowsUpdate)
		{
			Write-Debug "Set source of updates to Windows Update"
			$objSearcher.ServerSelection = 2
			$serviceName = "Windows Update"
		} #End If $WindowsUpdate
		ElseIf($MicrosoftUpdate)
		{
			Write-Debug "Set source of updates to Microsoft Update"
			$serviceName = $null
			Foreach ($objService in $objServiceManager.Services) 
			{
				If($objService.Name -eq "Microsoft Update")
				{
					$objSearcher.ServerSelection = 3
					$objSearcher.ServiceID = $objService.ServiceID
					$serviceName = $objService.Name
					Break
				}#End If $objService.Name -eq "Microsoft Update"
			}#End ForEach $objService in $objServiceManager.Services
			
			If(-not $serviceName)
			{
				Write-Warning "Can't find registered service Microsoft Update. Use Get-WUServiceManager to get registered service."
				Return
			}#Enf If -not $serviceName
		} #End Else $WindowsUpdate If $MicrosoftUpdate
		Else
		{
			Foreach ($objService in $objServiceManager.Services) 
			{
				If($ServiceID)
				{
					If($objService.ServiceID -eq $ServiceID)
					{
						$objSearcher.ServiceID = $ServiceID
						$objSearcher.ServerSelection = 3
						$serviceName = $objService.Name
						Break
					} #End If $objService.ServiceID -eq $ServiceID
				} #End If $ServiceID
				Else
				{
					If($objService.IsDefaultAUService -eq $True)
					{
						$serviceName = $objService.Name
						Break
					} #End If $objService.IsDefaultAUService -eq $True
				} #End Else $ServiceID
			} #End Foreach $objService in $objServiceManager.Services
		} #End Else $MicrosoftUpdate
		Write-Debug "Set source of updates to $serviceName"
		
		Write-Verbose "Connecting to $serviceName server. Please wait..."
		Try
		{
			$search = ""
			
			If($Criteria)
			{
				$search = $Criteria
			} #End If $Criteria
			Else
			{
				If($IsInstalled) 
				{
					$search = "IsInstalled = 1"
					Write-Debug "Set pre search criteria: IsInstalled = 1"
				} #End If $IsInstalled
				Else
				{
					$search = "IsInstalled = 0"	
					Write-Debug "Set pre search criteria: IsInstalled = 0"
				} #End Else $IsInstalled
				
				If($UpdateType -ne "")
				{
					Write-Debug "Set pre search criteria: Type = $UpdateType"
					$search += " and Type = '$UpdateType'"
				} #End If $UpdateType -ne ""					
				
				If($UpdateID)
				{
					Write-Debug "Set pre search criteria: UpdateID = '$([string]::join(", ", $UpdateID))'"
					$tmp = $search
					$search = ""
					$LoopCount = 0
					Foreach($ID in $UpdateID)
					{
						If($LoopCount -gt 0)
						{
							$search += " or "
						} #End If $LoopCount -gt 0
						If($RevisionNumber)
						{
							Write-Debug "Set pre search criteria: RevisionNumber = '$RevisionNumber'"	
							$search += "($tmp and UpdateID = '$ID' and RevisionNumber = $RevisionNumber)"
						} #End If $RevisionNumber
						Else
						{
							$search += "($tmp and UpdateID = '$ID')"
						} #End Else $RevisionNumber
						$LoopCount++
					} #End Foreach $ID in $UpdateID
				} #End If $UpdateID

				If($CategoryIDs)
				{
					Write-Debug "Set pre search criteria: CategoryIDs = '$([string]::join(", ", $CategoryIDs))'"
					$tmp = $search
					$search = ""
					$LoopCount =0
					Foreach($ID in $CategoryIDs)
					{
						If($LoopCount -gt 0)
						{
							$search += " or "
						} #End If $LoopCount -gt 0
						$search += "($tmp and CategoryIDs contains '$ID')"
						$LoopCount++
					} #End Foreach $ID in $CategoryIDs
				} #End If $CategoryIDs
				
				If($IsHidden) 
				{
					Write-Debug "Set pre search criteria: IsHidden = 1"
					$search += " and IsHidden = 1"	
				} #End If $IsNotHidden
				ElseIf($WithHidden) 
				{
					Write-Debug "Set pre search criteria: IsHidden = 1 and IsHidden = 0"
				} #End ElseIf $WithHidden
				Else
				{
					Write-Debug "Set pre search criteria: IsHidden = 0"
					$search += " and IsHidden = 0"	
				} #End Else $WithHidden
				
				#Don't know why every update have RebootRequired=false which is not always true
				If($IgnoreRebootRequired) 
				{
					Write-Debug "Set pre search criteria: RebootRequired = 0"
					$search += " and RebootRequired = 0"	
				} #End If $IgnoreRebootRequired
			} #End Else $Criteria
			
			Write-Debug "Search criteria is: $search"
			
			If($ShowSearchCriteria)
			{
				Write-Output $search
			} #End If $ShowSearchCriteria
			
			$objResults = $objSearcher.Search($search)
		} #End Try
		Catch
		{
			If($_ -match "HRESULT: 0x80072EE2")
			{
				Write-Warning "Probably you don't have connection to Windows Update server"
			} #End If $_ -match "HRESULT: 0x80072EE2"
			Return
		} #End Catch

		$objCollectionUpdate = New-Object -ComObject "Microsoft.Update.UpdateColl" 
		
		$NumberOfUpdate = 1
		$UpdateCollection = @()
		$UpdatesExtraDataCollection = @{}
		$PreFoundUpdatesToDownload = $objResults.Updates.count
		Write-Verbose "Found [$PreFoundUpdatesToDownload] Updates in pre search criteria"				

        if($RootCategories)
        {
            $RootCategoriesCollection = @()
            foreach($RootCategory in $RootCategories)
            {
                switch ($RootCategory) 
                { 
                    "Critical Updates" {$CatID = 0} 
                    "Definition Updates"{$CatID = 1} 
                    "Drivers"{$CatID = 2} 
                    "Feature Packs"{$CatID = 3} 
                    "Security Updates"{$CatID = 4} 
                    "Service Packs"{$CatID = 5} 
                    "Tools"{$CatID = 6} 
                    "Update Rollups"{$CatID = 7} 
                    "Updates"{$CatID = 8} 
                    "Upgrades"{$CatID = 9} 
                    "Microsoft"{$CatID = 10} 
                } #End switch $RootCategory
                $RootCategoriesCollection += $objResults.RootCategories.item($CatID).Updates
            } #End foreach $RootCategory in $RootCategories
            $objResults = New-Object -TypeName psobject -Property @{Updates = $RootCategoriesCollection}
        } #End if $RootCategories

		Foreach($Update in $objResults.Updates)
		{	
			$UpdateAccess = $true
			Write-Progress -Activity "Post search updates for $Computer" -Status "[$NumberOfUpdate/$PreFoundUpdatesToDownload] $($Update.Title) $size" -PercentComplete ([int]($NumberOfUpdate/$PreFoundUpdatesToDownload * 100))
			Write-Debug "Set post search criteria: $($Update.Title)"
			
			If($Category -ne "")
			{
				$UpdateCategories = $Update.Categories | Select-Object Name
				Write-Debug "Set post search criteria: Categories = '$([string]::join(", ", $Category))'"	
				Foreach($Cat in $Category)
				{
					If(!($UpdateCategories -match $Cat))
					{
						Write-Debug "UpdateAccess: false"
						$UpdateAccess = $false
					} #End If !($UpdateCategories -match $Cat)
					Else
					{
						$UpdateAccess = $true
						Break
					} #End Else !($UpdateCategories -match $Cat)
				} #End Foreach $Cat in $Category	
			} #End If $Category -ne ""

			If($NotCategory -ne "" -and $UpdateAccess -eq $true)
			{
				$UpdateCategories = $Update.Categories | Select-Object Name
				Write-Debug "Set post search criteria: NotCategories = '$([string]::join(", ", $NotCategory))'"	
				Foreach($Cat in $NotCategory)
				{
					If($UpdateCategories -match $Cat)
					{
						Write-Debug "UpdateAccess: false"
						$UpdateAccess = $false
						Break
					} #End If $UpdateCategories -match $Cat
				} #End Foreach $Cat in $NotCategory	
			} #End If $NotCategory -ne "" -and $UpdateAccess -eq $true					
			
			If($KBArticleID -ne $null -and $UpdateAccess -eq $true)
			{
				Write-Debug "Set post search criteria: KBArticleIDs = '$([string]::join(", ", $KBArticleID))'"
				If(!($KBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs))
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If !($KBArticleID -match $Update.KBArticleIDs)								
			} #End If $KBArticleID -ne $null -and $UpdateAccess -eq $true

			If($NotKBArticleID -ne $null -and $UpdateAccess -eq $true)
			{
				Write-Debug "Set post search criteria: NotKBArticleIDs = '$([string]::join(", ", $NotKBArticleID))'"
				If($NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If$NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs					
			} #End If $NotKBArticleID -ne $null -and $UpdateAccess -eq $true
			
			If($Title -and $UpdateAccess -eq $true)
			{
				Write-Debug "Set post search criteria: Title = '$Title'"
				If($Update.Title -notmatch $Title)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $Update.Title -notmatch $Title
			} #End If $Title -and $UpdateAccess -eq $true

			If($NotTitle -and $UpdateAccess -eq $true)
			{
				Write-Debug "Set post search criteria: NotTitle = '$NotTitle'"
				If($Update.Title -match $NotTitle)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $Update.Title -notmatch $NotTitle
			} #End If $NotTitle -and $UpdateAccess -eq $true

			If($Severity -and $UpdateAccess -eq $true)
			{
				if($Severity -contains "Unspecified") { $Severity += "" } 
                Write-Debug "Set post search criteria: Severity = '$Severity'"
				If($Severity -notcontains [String]$Update.MsrcSeverity)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $Severity -notcontains $Update.MsrcSeverity
			} #End If $Severity -and $UpdateAccess -eq $true

			If($NotSeverity -and $UpdateAccess -eq $true)
			{
				if($NotSeverity -contains "Unspecified") { $NotSeverity += "" } 
                Write-Debug "Set post search criteria: NotSeverity = '$NotSeverity'"
				If($NotSeverity -contains [String]$Update.MsrcSeverity)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $NotSeverity -contains $Update.MsrcSeverity
			} #End If $NotSeverity -and $UpdateAccess -eq $true

			If($MaxSize -and $UpdateAccess -eq $true)
			{
                Write-Debug "Set post search criteria: MaxDownloadSize <= '$MaxSize'"
				If($MaxSize -le $Update.MaxDownloadSize)
				{
				    Write-Debug "UpdateAccess: false"
				    $UpdateAccess = $false
			    } #End If $MaxSize -le $Update.MaxDownloadSize
		    } #End If $MaxSize -and $UpdateAccess -eq $true

			If($MinSize -and $UpdateAccess -eq $true)
			{
                Write-Debug "Set post search criteria: MaxDownloadSize >= '$MinSize'"
			    If($MinSize -ge $Update.MaxDownloadSize)
			    {
			        Write-Debug "UpdateAccess: false"
			        $UpdateAccess = $false
			    } #End If $MinSize -ge $Update.MaxDownloadSize
			} #End If $MinSize -and $UpdateAccess -eq $true
			
			If($IgnoreUserInput -and $UpdateAccess -eq $true)
			{
				Write-Debug "Set post search criteria: CanRequestUserInput"
				If($Update.InstallationBehavior.CanRequestUserInput -eq $true)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $Update.InstallationBehavior.CanRequestUserInput -eq $true
			} #End If $IgnoreUserInput -and $UpdateAccess -eq $true

			If($IgnoreRebootRequired -and $UpdateAccess -eq $true) 
			{
				Write-Debug "Set post search criteria: RebootBehavior"
				If($Update.InstallationBehavior.RebootBehavior -ne 0)
				{
					Write-Debug "UpdateAccess: false"
					$UpdateAccess = $false
				} #End If $Update.InstallationBehavior.RebootBehavior -ne 0	
			} #End If $IgnoreRebootRequired -and $UpdateAccess -eq $true

			If($UpdateAccess -eq $true)
			{
				Write-Debug "Convert size"
				Switch($Update.MaxDownloadSize)
				{
					{[System.Math]::Round($_/1KB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1KB,0))+" KB"; break }
					{[System.Math]::Round($_/1MB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1MB,0))+" MB"; break }  
					{[System.Math]::Round($_/1GB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1GB,0))+" GB"; break }    
					{[System.Math]::Round($_/1TB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1TB,0))+" TB"; break }
					default { $size = $_+"B" }
				} #End Switch
			
				Write-Debug "Convert KBArticleIDs"
				If($Update.KBArticleIDs -ne "")    
				{
					$KB = "KB"+$Update.KBArticleIDs
				} #End If $Update.KBArticleIDs -ne ""
				Else 
				{
					$KB = ""
				} #End Else $Update.KBArticleIDs -ne ""
				
				If($ListOnly)
				{
					$Status = ""
					If($Update.IsDownloaded)    {$Status += "D"} else {$status += "-"}
					If($Update.IsInstalled)     {$Status += "I"} else {$status += "-"}
					If($Update.IsMandatory)     {$Status += "M"} else {$status += "-"}
					If($Update.IsHidden)        {$Status += "H"} else {$status += "-"}
					If($Update.IsUninstallable) {$Status += "U"} else {$status += "-"}
					If($Update.IsBeta)          {$Status += "B"} else {$status += "-"} 
	
					Add-Member -InputObject $Update -MemberType NoteProperty -Name ComputerName -Value $env:COMPUTERNAME
					Add-Member -InputObject $Update -MemberType NoteProperty -Name KB -Value $KB
					Add-Member -InputObject $Update -MemberType NoteProperty -Name Size -Value $size
					Add-Member -InputObject $Update -MemberType NoteProperty -Name Status -Value $Status
					Add-Member -InputObject $Update -MemberType NoteProperty -Name X -Value 1
					
					$Update.PSTypeNames.Clear()
					$Update.PSTypeNames.Add('PSWindowsUpdate.WUInstall')
					$UpdateCollection += $Update
				} #End If $ListOnly
				Else
				{
					$objCollectionUpdate.Add($Update) | Out-Null
					$UpdatesExtraDataCollection.Add($Update.Identity.UpdateID,@{KB = $KB; Size = $size})
				} #End Else $ListOnly
			} #End If $UpdateAccess -eq $true
			
			$NumberOfUpdate++
		} #End Foreach $Update in $objResults.Updates				
		Write-Progress -Activity "[1/$NumberOfStage] Post search updates" -Status "Completed" -Completed
		
		If($ListOnly)
		{
			$FoundUpdatesToDownload = $UpdateCollection.count
		} #End If $ListOnly
		Else
		{
			$FoundUpdatesToDownload = $objCollectionUpdate.count				
		} #End Else $ListOnly
		Write-Verbose "Found [$FoundUpdatesToDownload] Updates in post search criteria"
		
		If($FoundUpdatesToDownload -eq 0)
		{
			Return
		} #End If $FoundUpdatesToDownload -eq 0
		
		If($ListOnly)
		{
			Write-Debug "Return only list of updates"
			Return $UpdateCollection				
		} #End If $ListOnly

		#################################
		# End STAGE 1: Get updates list #
		#################################
		#endregion
		

		If(!$ListOnly) 
		{
			#region	STAGE 2
			#################################
			# Start STAGE 2: Choose updates #
			#################################
			
			Write-Debug "STAGE 2: Choose updates"			
			$NumberOfUpdate = 1
			$logCollection = @()
			
			$objCollectionChoose = New-Object -ComObject "Microsoft.Update.UpdateColl"

			Foreach($Update in $objCollectionUpdate)
			{	
				$size = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].Size
				Write-Progress -Activity "[2/$NumberOfStage] Choose updates" -Status "[$NumberOfUpdate/$FoundUpdatesToDownload] $($Update.Title) $size" -PercentComplete ([int]($NumberOfUpdate/$FoundUpdatesToDownload * 100))
				Write-Debug "Show update to accept: $($Update.Title)"
				
				If($AcceptAll)
				{
					$Status = "Accepted"

					If($Update.EulaAccepted -eq 0)
					{ 
						Write-Debug "Accept Eula"
						$Update.AcceptEula() 
					} #End If $Update.EulaAccepted -eq 0
			
					Write-Debug "Add update to collection"
					$objCollectionChoose.Add($Update) | Out-Null
				} #End If $AcceptAll
				ElseIf($AutoSelectOnly)  
				{  
					If($Update.AutoSelectOnWebsites)  
					{  
						$Status = "Accepted"  
						If($Update.EulaAccepted -eq 0)  
						{  
							Write-Debug "Accept Eula"  
							$Update.AcceptEula()  
						} #End If $Update.EulaAccepted -eq 0  
  
						Write-Debug "Add update to collection"  
						$objCollectionChoose.Add($Update) | Out-Null  
					} #End If $Update.AutoSelectOnWebsites 
					Else  
					{  
						$Status = "Rejected"  
					} #End Else $Update.AutoSelectOnWebsites
				} #End ElseIf $AutoSelectOnly
				Else
				{
					If($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"$($Update.Title)[$size]?")) 
					{
						$Status = "Accepted"
						
						If($Update.EulaAccepted -eq 0)
						{ 
							Write-Debug "Accept Eula"
							$Update.AcceptEula() 
						} #End If $Update.EulaAccepted -eq 0
				
						Write-Debug "Add update to collection"
						$objCollectionChoose.Add($Update) | Out-Null 
					} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"$($Update.Title)[$size]?")
					Else
					{
						$Status = "Rejected"
					} #End Else $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"$($Update.Title)[$size]?")
				} #End Else $AutoSelectOnly
				
				Write-Debug "Add to log collection"
				$log = New-Object PSObject -Property @{
					Title = $Update.Title
					KB = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].KB
					Size = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].Size
					Status = $Status
					X = 2
				} #End PSObject Property
				
				$log.PSTypeNames.Clear()
				$log.PSTypeNames.Add('PSWindowsUpdate.WUInstall')
				
				$logCollection += $log
				
				$NumberOfUpdate++
			} #End Foreach $Update in $objCollectionUpdate
			Write-Progress -Activity "[2/$NumberOfStage] Choose updates" -Status "Completed" -Completed
			
			Write-Debug "Show log collection"
			$logCollection
			
			
			$AcceptUpdatesToDownload = $objCollectionChoose.count
			Write-Verbose "Accept [$AcceptUpdatesToDownload] Updates to Download"
			
			If($AcceptUpdatesToDownload -eq 0)
			{
				Return
			} #End If $AcceptUpdatesToDownload -eq 0	
				
			###############################
			# End STAGE 2: Choose updates #
			###############################
			#endregion
			
			#region STAGE 3
			###################################
			# Start STAGE 3: Download updates #
			###################################
			
			Write-Debug "STAGE 3: Download updates"
			$NumberOfUpdate = 1
			$objCollectionDownload = New-Object -ComObject "Microsoft.Update.UpdateColl" 

			Foreach($Update in $objCollectionChoose)
			{
				Write-Progress -Activity "[3/$NumberOfStage] Downloading updates" -Status "[$NumberOfUpdate/$AcceptUpdatesToDownload] $($Update.Title) $size" -PercentComplete ([int]($NumberOfUpdate/$AcceptUpdatesToDownload * 100))
				Write-Debug "Show update to download: $($Update.Title)"
				
				Write-Debug "Send update to download collection"
				$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
				$objCollectionTmp.Add($Update) | Out-Null
					
				$Downloader = $objSession.CreateUpdateDownloader() 
				$Downloader.Updates = $objCollectionTmp
				Try
				{
					Write-Debug "Try download update"
					$DownloadResult = $Downloader.Download()
				} #End Try
				Catch
				{
					If($_ -match "HRESULT: 0x80240044")
					{
						Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
					} #End If $_ -match "HRESULT: 0x80240044"
					
					Return
				} #End Catch 
				
				Write-Debug "Check ResultCode"
				Switch -exact ($DownloadResult.ResultCode)
				{
					0   { $Status = "NotStarted" }
					1   { $Status = "InProgress" }
					2   { $Status = "Downloaded" }
					3   { $Status = "DownloadedWithErrors" }
					4   { $Status = "Failed" }
					5   { $Status = "Aborted" }
				} #End Switch
				
				Write-Debug "Add to log collection"
				$log = New-Object PSObject -Property @{
					Title = $Update.Title
					KB = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].KB
					Size = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].Size
					Status = $Status
					X = 3
				} #End PSObject Property
				
				$log.PSTypeNames.Clear()
				$log.PSTypeNames.Add('PSWindowsUpdate.WUInstall')
				
				$log
				
				If($DownloadResult.ResultCode -eq 2)
				{
					Write-Debug "Downloaded then send update to next stage"
					$objCollectionDownload.Add($Update) | Out-Null
				} #End If $DownloadResult.ResultCode -eq 2
				
				$NumberOfUpdate++
				
			} #End Foreach $Update in $objCollectionChoose
			Write-Progress -Activity "[3/$NumberOfStage] Downloading updates" -Status "Completed" -Completed

			$ReadyUpdatesToInstall = $objCollectionDownload.count
			Write-Verbose "Downloaded [$ReadyUpdatesToInstall] Updates to Install"
		
			If($ReadyUpdatesToInstall -eq 0)
			{
				Return
			} #End If $ReadyUpdatesToInstall -eq 0
		

			#################################
			# End STAGE 3: Download updates #
			#################################
			#endregion
			
			If(!$DownloadOnly)
			{
				#region	STAGE 4
				##################################
				# Start STAGE 4: Install updates #
				##################################
				
				Write-Debug "STAGE 4: Install updates"
				$NeedsReboot = $false
				$NumberOfUpdate = 1
				
				#install updates	
				Foreach($Update in $objCollectionDownload)
				{   
					Write-Progress -Activity "[4/$NumberOfStage] Installing updates" -Status "[$NumberOfUpdate/$ReadyUpdatesToInstall] $($Update.Title)" -PercentComplete ([int]($NumberOfUpdate/$ReadyUpdatesToInstall * 100))
					Write-Debug "Show update to install: $($Update.Title)"
					
					Write-Debug "Send update to install collection"
					$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
					$objCollectionTmp.Add($Update) | Out-Null
					
					$objInstaller = $objSession.CreateUpdateInstaller()
					$objInstaller.Updates = $objCollectionTmp
						
					Try
					{
						Write-Debug "Try install update"
						$InstallResult = $objInstaller.Install()
					} #End Try
					Catch
					{
						If($_ -match "HRESULT: 0x80240044")
						{
							Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
						} #End If $_ -match "HRESULT: 0x80240044"
						
						Return
					} #End Catch
					
					If(!$NeedsReboot) 
					{ 
						Write-Debug "Set instalation status RebootRequired"
						$NeedsReboot = $installResult.RebootRequired 
					} #End If !$NeedsReboot
					
					Switch -exact ($InstallResult.ResultCode)
					{
						0   { $Status = "NotStarted"}
						1   { $Status = "InProgress"}
						2   { $Status = "Installed"}
						3   { $Status = "InstalledWithErrors"}
						4   { $Status = "Failed"}
						5   { $Status = "Aborted"}
					} #End Switch
				   
					Write-Debug "Add to log collection"
					$log = New-Object PSObject -Property @{
						Title = $Update.Title
						KB = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].KB
						Size = $UpdatesExtraDataCollection[$Update.Identity.UpdateID].Size
						Status = $Status
						X = 4
					} #End PSObject Property
					
					$log.PSTypeNames.Clear()
					$log.PSTypeNames.Add('PSWindowsUpdate.WUInstall')
					
					$log
				
					$NumberOfUpdate++
				} #End Foreach $Update in $objCollectionDownload
				Write-Progress -Activity "[4/$NumberOfStage] Installing updates" -Status "Completed" -Completed
				
				If($NeedsReboot)
				{
					If($AutoReboot)
					{
						Restart-Computer -Force
					} #End If $AutoReboot
					ElseIf($IgnoreReboot)
					{
						Return "Reboot is required, but do it manually."
					} #End Else $AutoReboot If $IgnoreReboot
					Else
					{
						$Reboot = Read-Host "Reboot is required. Do it now ? [Y/N]"
						If($Reboot -eq "Y")
						{
							Restart-Computer -Force
						} #End If $Reboot -eq "Y"
						
					} #End Else $IgnoreReboot	
					
				} #End If $NeedsReboot

				################################
				# End STAGE 4: Install updates #
				################################
				#endregion
			} #End If !$DownloadOnly
		} #End !$ListOnly
	} #End Process
	
	End{}		
} #In The End :)


Function Get-WUInstallerStatus
{
    <#
	.SYNOPSIS
	    Show Windows Update Installer status.

	.DESCRIPTION
	    Use Get-WUInstallerStatus to show Windows Update Installer status.

	.PARAMETER Silent
	    Get only status True/False without any more comments on screen.
		
	.EXAMPLE
		Check if Windows Update Installer is busy.
		
		PS C:\> Get-WUInstallerStatus
		Installer is ready.

	.EXAMPLE
		Check if Windows Update Installer is busy in silent mode. Return only True (isBusy) or False (isFree).
		
		PS C:\> Get-WUInstallerStatus -Silent
		False

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
        Get-WURebootStatus
	#>
	
	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param
	(
		[Switch]$Silent
	)
	
	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role	
	}
	
	Process
	{
        If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Check that Windows Installer is ready to install next updates")) 
		{	    
			$objInstaller=New-Object -ComObject "Microsoft.Update.Installer"
			
			Switch($objInstaller.IsBusy)
			{
				$true	{ If($Silent) {Return $true} Else {Write-Output "Installer is busy."}}
				$false	{ If($Silent) {Return $false} Else {Write-Output "Installer is ready."}}
			} #End Switch $objInstaller.IsBusy
			
		} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Check that Windows Installer is ready to install next updates")
	} #End Process
	
	End{}	
} #In The End :)

Function Get-WUList
{
	<#
	.SYNOPSIS
	    Get list of available updates meeting the criteria.

	.DESCRIPTION
	    Use Get-WUList to get list of available or installed updates meeting specific criteria.
		There are two types of filtering update: Pre search criteria, Post search criteria.
		- Pre search works on server side, like example: ( IsInstalled = 0 and IsHidden = 0 and CategoryIds contains '0fa1201d-4330-4fa8-8ae9-b877473b6441' )
		- Post search work on client side after downloading the pre-filtered list of updates, like example $KBArticleID -match $Update.KBArticleIDs

		Status list:
        D - IsDownloaded, I - IsInstalled, M - IsMandatory, H - IsHidden, U - IsUninstallable, B - IsBeta
		
	.PARAMETER UpdateType
		Pre search criteria. Finds updates of a specific type, such as 'Driver' and 'Software'. Default value contains all updates.

	.PARAMETER UpdateID
		Pre search criteria. Finds updates of a specific UUID (or sets of UUIDs), such as '12345678-9abc-def0-1234-56789abcdef0'.

	.PARAMETER RevisionNumber
		Pre search criteria. Finds updates of a specific RevisionNumber, such as '100'. This criterion must be combined with the UpdateID param.

	.PARAMETER CategoryIDs
		Pre search criteria. Finds updates that belong to a specified category (or sets of UUIDs), such as '0fa1201d-4330-4fa8-8ae9-b877473b6441'.

	.PARAMETER IsInstalled
		Pre search criteria. Finds updates that are installed on the destination computer.

	.PARAMETER IsHidden
		Pre search criteria. Finds updates that are marked as hidden on the destination computer.
	
	.PARAMETER IsNotHidden
		Pre search criteria. Finds updates that are not marked as hidden on the destination computer. Overwrite IsHidden param.
			
	.PARAMETER Criteria
		Pre search criteria. Set own string that specifies the search criteria.

	.PARAMETER ShowSearchCriteria
		Show choosen search criteria. Only works for pre search criteria.

	.PARAMETER RootCategories
		Post search criteria. Finds updates that contain a specified root category name 'Critical Updates', 'Definition Updates', 'Drivers', 'Feature Packs', 'Security Updates', 'Service Packs', 'Tools', 'Update Rollups', 'Updates', 'Upgrades', 'Microsoft'

	.PARAMETER Category
		Post search criteria. Finds updates that contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER KBArticleID
		Post search criteria. Finds updates that contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER Title
		Post search criteria. Finds updates that match part of title, such as ''

	.PARAMETER Severity
		Post search criteria. Finds updates that match part of severity, such as 'Important', 'Critical', 'Moderate', etc...

	.PARAMETER NotCategory
		Post search criteria. Finds updates that not contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER NotKBArticleID
		Post search criteria. Finds updates that not contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER NotTitle
		Post search criteria. Finds updates that not match part of title.
			
	.PARAMETER NotSeverity
		Post search criteria. Finds updates that not match part of severity.

	.PARAMETER MaxSize
		Post search criteria. Finds updates that have MaxDownloadSize less or equal. Size is in Bytes.

	.PARAMETER MinSize
		Post search criteria. Finds updates that have MaxDownloadSize greater or equal. Size is in Bytes.
		
	.PARAMETER IgnoreUserInput
		Post search criteria. Finds updates that the installation or uninstallation of an update can't prompt for user input.
	
	.PARAMETER IgnoreRebootRequired
		Post search criteria. Finds updates that specifies the restart behavior that not occurs when you install or uninstall the update.
	
	.PARAMETER ServiceID
		Set ServiceIS to change the default source of Windows Updates. It overwrite ServerSelection parameter value.

	.PARAMETER WindowsUpdate
		Set Windows Update Server as source. Default update config are taken from computer policy.
		
	.PARAMETER MicrosoftUpdate
		Set Microsoft Update Server as source. Default update config are taken from computer policy.
		
	.PARAMETER ComputerName	
	    Specify the name of the computer to the remote connection.
	
	.PARAMETER AutoSelectOnly  
		Install only the updates that have status AutoSelectOnWebsites on true.		

	.PARAMETER Debuger	
	    Debug mode.

	.EXAMPLE
		Get list of available updates from Microsoft Update Server.
	
		PS C:\> Get-WUList -MicrosoftUpdate

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		KOMPUTER     ------ KB976002  102 KB Aktualizacja firmy Microsoft z ekranem wybierania przeglądarki dla użytkowników...
		KOMPUTER     ------ KB971033    1 MB Aktualizacja dla systemu Windows 7 dla systemów opartych na procesorach x64 (KB...
		KOMPUTER     ------ KB2533552   9 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2533552)
		KOMPUTER     ------ KB982861   37 MB Windows Internet Explorer 9 dla systemu Windows 7 - wersja dla systemów opartyc...
		KOMPUTER     D----- KB982670   48 MB Program Microsoft .NET Framework 4 Client Profile w systemie Windows 7 dla syst...
		KOMPUTER     ---H-- KB890830    1 MB Narzędzie Windows do usuwania złośliwego oprogramowania dla komputerów z proces...

	.EXAMPLE
		Get list of critical or security updates.
	
		PS C:\> Get-WUList -RootCategories 'Critical Updates','Security Updates' 

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		KOMPUTER     ------ KB3156059 287 KB Security Update for Windows Server 2012 R2 (KB3156059)
		KOMPUTER     ------ KB3156059   1 MB Security Update for Windows Server 2012 R2 (KB3156059)

	.EXAMPLE
		Get information about updates from Microsoft Update Server that are installed on remote machine G1. Updates type are software, from specific category, have specific UUID and Revision Name.
		
		PS C:\> $UpdateIDs = "40336e0a-7b9b-45a0-89e9-9bd3ce0c3137","61bfe3ec-a1dc-4eab-9481-0d8fd7319ae8","0c737c40-b687-45bc-8
		deb-83db8209b258"
		PS C:\> Get-WUList -MicrosoftUpdate -IsInstalled -Type "Software" -CategoryIDs "E6CF1350-C01B-414D-A61F-263D14D133B4" -U
		pdateID $UpdateIDs -RevisionNumber 101 -ComputerName G1 -Verbose
		VERBOSE: Connecting to Microsoft Update server. Please wait...
		VERBOSE: Found [2] Updates in pre search criteria
		VERBOSE: Found [2] Updates in post search criteria

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		G1           DI--U- KB2345886 605 KB Aktualizacja dla systemu Windows 7 dla systemów opartych na procesorach x64 (KB...
		G1           DI--U- KB2641690  67 KB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2641690)

	.EXAMPLE
		Hide updates contains "Internet Explorer 9" in title and are in "Update Rollups" category.
		
		PS C:\> $UpdatesList = Get-WUList -ServiceID "9482f4b4-e343-43b6-b170-9a65bc822c77" -Title "Internet Explorer 9" -Catego
		ry "Update Rollups"
		PS C:\> $UpdatesList.IsHidden = $true
		PS C:\> Get-WUList -ServiceID "9482f4b4-e343-43b6-b170-9a65bc822c77" -Title "Internet Explorer 9" -Category "Update Roll
		ups" -IsHidden

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		KOMPUTER     ---H-- KB982861   37 MB Windows Internet Explorer 9 dla systemu Windows 7 - wersja dla systemów opartyc...

	.EXAMPLE
		Get list of updates without language packs and updatets that's not hidden.
	
		PS C:\> Get-WUList -NotCategory "Language packs" -IsNotHidden

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		G1           ------ KB2640148   8 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2640148)
		G1           ------ KB2600217  32 MB Aktualizacja dla programu Microsoft .NET Framework 4 w systemach Windows XP, Se...
		G1           ------ KB2679255   6 MB Aktualizacja systemu Windows 7 dla komputerów z procesorami x64 (KB2679255)
		G1           ------ KB915597    3 MB Definition Update for Windows Defender - KB915597 (Definition 1.125.146.0)
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
		http://msdn.microsoft.com/en-us/library/windows/desktop/aa386526(v=vs.85).aspx
		http://msdn.microsoft.com/en-us/library/windows/desktop/aa386099(v=vs.85).aspx
		http://msdn.microsoft.com/en-us/library/ff357803(VS.85).aspx

	.LINK
		Get-WUServiceManager
		Get-WUInstall
	#>

	[OutputType('PSWindowsUpdate.WUList')]
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]	
	Param
	(
		#Pre search criteria
		[ValidateSet("Driver", "Software")]
		[String]$UpdateType="",
		[String[]]$UpdateID,
		[Int]$RevisionNumber,
		[String[]]$CategoryIDs,
		[Switch]$IsInstalled,
		[Switch]$IsHidden,
		[Switch]$IsNotHidden,
		[String]$Criteria,
		[Switch]$ShowSearchCriteria,		
		
		#Post search criteria
        [ValidateSet("Critical Updates", "Definition Updates", "Drivers", "Feature Packs", "Security Updates", "Service Packs", "Tools", "Update Rollups", "Updates", "Upgrades", "Microsoft")]
        [String[]]$RootCategories,
		[String[]]$Category="",
		[String[]]$KBArticleID,
		[String]$Title,
        [ValidateSet("Critical", "Important", "Moderate", "Low", "Unspecified", "")]
		[String[]]$Severity,

		[String[]]$NotCategory="",
		[String[]]$NotKBArticleID,
		[String]$NotTitle,
        [ValidateSet("Critical", "Important", "Moderate", "Low", "Unspecified")]
		[String[]]$NotSeverity,
        [Int]$MaxSize,
        [Int]$MinSize,

		[Alias("Silent")]
		[Switch]$IgnoreUserInput,
		[Switch]$IgnoreRebootRequired,
		[Switch]$AutoSelectOnly,		
		
		#Connection options
		[String]$ServiceID,
		[Switch]$WindowsUpdate,
		[Switch]$MicrosoftUpdate,
		
		#Mode options
		[Switch]$Debuger,
		[parameter(ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true)]
		[String[]]$ComputerName
	)

	Begin
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger']
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role		
	}

	Process
	{
		Write-Debug "STAGE 0: Prepare environment"
		######################################
		# Start STAGE 0: Prepare environment #
		######################################
		
		Write-Debug "Check if ComputerName in set"
		If($ComputerName -eq $null)
		{
			Write-Debug "Set ComputerName to localhost"
			[String[]]$ComputerName = $env:COMPUTERNAME
		} #End If $ComputerName -eq $null
		
		####################################			
		# End STAGE 0: Prepare environment #
		####################################
		
		$UpdateCollection = @()
		Foreach($Computer in $ComputerName)
		{
			If(Test-Connection -ComputerName $Computer -Quiet)
			{
				Write-Debug "STAGE 1: Get updates list"
				###################################
				# Start STAGE 1: Get updates list #
				###################################			

				If($Computer -eq $env:COMPUTERNAME)
				{
					Write-Debug "Create Microsoft.Update.ServiceManager object"
					$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager" #Support local instance only
					Write-Debug "Create Microsoft.Update.Session object for $Computer"
					$objSession = New-Object -ComObject "Microsoft.Update.Session" #Support local instance only
				} #End If $Computer -eq $env:COMPUTERNAME
				Else
				{
					Write-Debug "Create Microsoft.Update.Session object for $Computer"
					$objSession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Computer))
				} #End Else $Computer -eq $env:COMPUTERNAME
				
				Write-Debug "Create Microsoft.Update.Session.Searcher object for $Computer"
				$objSearcher = $objSession.CreateUpdateSearcher()

				If($WindowsUpdate)
				{
					Write-Debug "Set source of updates to Windows Update"
					$objSearcher.ServerSelection = 2
					$serviceName = "Windows Update"
				} #End If $WindowsUpdate
				ElseIf($MicrosoftUpdate)
				{
					Write-Debug "Set source of updates to Microsoft Update"
					$serviceName = $null
					Foreach ($objService in $objServiceManager.Services) 
					{
						If($objService.Name -eq "Microsoft Update")
						{
							$objSearcher.ServerSelection = 3
							$objSearcher.ServiceID = $objService.ServiceID
							$serviceName = $objService.Name
							Break
						}#End If $objService.Name -eq "Microsoft Update"
					}#End ForEach $objService in $objServiceManager.Services
					
					If(-not $serviceName)
					{
						Write-Warning "Can't find registered service Microsoft Update. Use Get-WUServiceManager to get registered service."
						Return
					}#Enf If -not $serviceName
				} #End Else $WindowsUpdate If $MicrosoftUpdate
				ElseIf($Computer -eq $env:COMPUTERNAME) #Support local instance only
				{
					Foreach ($objService in $objServiceManager.Services) 
					{
						If($ServiceID)
						{
							If($objService.ServiceID -eq $ServiceID)
							{
								$objSearcher.ServiceID = $ServiceID
								$objSearcher.ServerSelection = 3
								$serviceName = $objService.Name
								Break
							} #End If $objService.ServiceID -eq $ServiceID
						} #End If $ServiceID
						Else
						{
							If($objService.IsDefaultAUService -eq $True)
							{
								$serviceName = $objService.Name
								Break
							} #End If $objService.IsDefaultAUService -eq $True
						} #End Else $ServiceID
					} #End Foreach $objService in $objServiceManager.Services
				} #End Else $MicrosoftUpdate If $Computer -eq $env:COMPUTERNAME
				ElseIf($ServiceID)
				{
					$objSearcher.ServiceID = $ServiceID
					$objSearcher.ServerSelection = 3
					$serviceName = $ServiceID
				}
				Else #End Else $Computer -eq $env:COMPUTERNAME If $ServiceID
				{
					$serviceName = "default (for $Computer) Windows Update"
				} #End Else $ServiceID
				Write-Debug "Set source of updates to $serviceName"
				
				Write-Verbose "Connecting to $serviceName server. Please wait..."
				Try
				{
					$search = ""
					If($Criteria)
					{
						$search = $Criteria
					} #End If $Criteria
					Else
					{
						If($IsInstalled) 
						{
							$search = "IsInstalled = 1"
							Write-Debug "Set pre search criteria: IsInstalled = 1"
						} #End If $IsInstalled
						Else
						{
							$search = "IsInstalled = 0"	
							Write-Debug "Set pre search criteria: IsInstalled = 0"
						} #End Else $IsInstalled
						
						If($UpdateType -ne "")
						{
							Write-Debug "Set pre search criteria: Type = $UpdateType"
							$search += " and Type = '$UpdateType'"
						} #End If $UpdateType -ne ""					
						
						If($UpdateID)
						{
							Write-Debug "Set pre search criteria: UpdateID = '$([string]::join(", ", $UpdateID))'"
							$tmp = $search
							$search = ""
							$LoopCount = 0
							Foreach($ID in $UpdateID)
							{
								If($LoopCount -gt 0)
								{
									$search += " or "
								} #End If $LoopCount -gt 0
								If($RevisionNumber)
								{
									Write-Debug "Set pre search criteria: RevisionNumber = '$RevisionNumber'"	
									$search += "($tmp and UpdateID = '$ID' and RevisionNumber = $RevisionNumber)"
								} #End If $RevisionNumber
								Else
								{
									$search += "($tmp and UpdateID = '$ID')"
								} #End Else $RevisionNumber
								$LoopCount++
							} #End Foreach $ID in $UpdateID
						} #End If $UpdateID

						If($CategoryIDs)
						{
							Write-Debug "Set pre search criteria: CategoryIDs = '$([string]::join(", ", $CategoryIDs))'"
							$tmp = $search
							$search = ""
							$LoopCount =0
							Foreach($ID in $CategoryIDs)
							{
								If($LoopCount -gt 0)
								{
									$search += " or "
								} #End If $LoopCount -gt 0
								$search += "($tmp and CategoryIDs contains '$ID')"
								$LoopCount++
							} #End Foreach $ID in $CategoryIDs
						} #End If $CategoryIDs
						
						If($IsNotHidden) 
						{
							Write-Debug "Set pre search criteria: IsHidden = 0"
							$search += " and IsHidden = 0"	
						} #End If $IsNotHidden
						ElseIf($IsHidden) 
						{
							Write-Debug "Set pre search criteria: IsHidden = 1"
							$search += " and IsHidden = 1"	
						} #End ElseIf $IsHidden

						#Don't know why every update have RebootRequired=false which is not always true
						If($IgnoreRebootRequired) 
						{
							Write-Debug "Set pre search criteria: RebootRequired = 0"
							$search += " and RebootRequired = 0"	
						} #End If $IgnoreRebootRequired
					} #End Else $Criteria
					
					Write-Debug "Search criteria is: $search"
					
					If($ShowSearchCriteria)
					{
						Write-Output $search
					} #End If $ShowSearchCriteria
			
					$objResults = $objSearcher.Search($search)
				} #End Try
				Catch
				{
					If($_ -match "HRESULT: 0x80072EE2")
					{
						Write-Warning "Probably you don't have connection to Windows Update server"
					} #End If $_ -match "HRESULT: 0x80072EE2"
					Return
				} #End Catch

				$NumberOfUpdate = 1
				$PreFoundUpdatesToDownload = $objResults.Updates.count
				Write-Verbose "Found [$PreFoundUpdatesToDownload] Updates in pre search criteria"				
				
				If($PreFoundUpdatesToDownload -eq 0)
				{
					Continue
				} #End If $PreFoundUpdatesToDownload -eq 0 
				
                if($RootCategories)
                {
                    $RootCategoriesCollection = @()
                    foreach($RootCategory in $RootCategories)
                    {
                        switch ($RootCategory) 
                        { 
                            "Critical Updates" {$CatID = 0} 
                            "Definition Updates"{$CatID = 1} 
                            "Drivers"{$CatID = 2} 
                            "Feature Packs"{$CatID = 3} 
                            "Security Updates"{$CatID = 4} 
                            "Service Packs"{$CatID = 5} 
                            "Tools"{$CatID = 6} 
                            "Update Rollups"{$CatID = 7} 
                            "Updates"{$CatID = 8} 
                            "Upgrades"{$CatID = 9} 
                            "Microsoft"{$CatID = 10} 
                        } #End switch $RootCategory
                        $RootCategoriesCollection += $objResults.RootCategories.item($CatID).Updates
                    } #End foreach $RootCategory in $RootCategories
                    $objResults = New-Object -TypeName psobject -Property @{Updates = $RootCategoriesCollection}
                } #End if $RootCategories

				Foreach($Update in $objResults.Updates)
				{	
					$UpdateAccess = $true
					Write-Progress -Activity "Post search updates for $Computer" -Status "[$NumberOfUpdate/$PreFoundUpdatesToDownload] $($Update.Title) $size" -PercentComplete ([int]($NumberOfUpdate/$PreFoundUpdatesToDownload * 100))
					Write-Debug "Set post search criteria: $($Update.Title)"
					
					If($Category -ne "")
					{
						$UpdateCategories = $Update.Categories | Select-Object Name
						Write-Debug "Set post search criteria: Categories = '$([string]::join(", ", $Category))'"	
						Foreach($Cat in $Category)
						{
							If(!($UpdateCategories -match $Cat))
							{
								Write-Debug "UpdateAccess: false"
								$UpdateAccess = $false
							} #End If !($UpdateCategories -match $Cat)
							Else
							{
								$UpdateAccess = $true
								Break
							} #End Else !($UpdateCategories -match $Cat)
						} #End Foreach $Cat in $Category	
					} #End If $Category -ne ""

					If($NotCategory -ne "" -and $UpdateAccess -eq $true)
					{
						$UpdateCategories = $Update.Categories | Select-Object Name
						Write-Debug "Set post search criteria: NotCategories = '$([string]::join(", ", $NotCategory))'"	
						Foreach($Cat in $NotCategory)
						{
							If($UpdateCategories -match $Cat)
							{
								Write-Debug "UpdateAccess: false"
								$UpdateAccess = $false
								Break
							} #End If $UpdateCategories -match $Cat
						} #End Foreach $Cat in $NotCategory	
					} #End If $NotCategory -ne "" -and $UpdateAccess -eq $true					
					
					If($KBArticleID -ne $null -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: KBArticleIDs = '$([string]::join(", ", $KBArticleID))'"
						If(!($KBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs))
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If !($KBArticleID -match $Update.KBArticleIDs)								
					} #End If $KBArticleID -ne $null -and $UpdateAccess -eq $true

					If($NotKBArticleID -ne $null -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: NotKBArticleIDs = '$([string]::join(", ", $NotKBArticleID))'"
						If($NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If$NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs					
					} #End If $NotKBArticleID -ne $null -and $UpdateAccess -eq $true
					
					If($Title -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: Title = '$Title'"
						If($Update.Title -notmatch $Title)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.Title -notmatch $Title
					} #End If $Title -and $UpdateAccess -eq $true

					If($NotTitle -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: NotTitle = '$NotTitle'"
						If($Update.Title -match $NotTitle)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.Title -notmatch $NotTitle
					} #End If $NotTitle -and $UpdateAccess -eq $true

			        If($Severity -and $UpdateAccess -eq $true)
			        {
				        if($Severity -contains "Unspecified") { $Severity += "" } 
                        Write-Debug "Set post search criteria: Severity = '$Severity'"
				        If($Severity -notcontains [String]$Update.MsrcSeverity)
				        {
					        Write-Debug "UpdateAccess: false"
					        $UpdateAccess = $false
				        } #End If $Severity -notcontains $Update.MsrcSeverity
			        } #End If $Severity -and $UpdateAccess -eq $true

			        If($NotSeverity -and $UpdateAccess -eq $true)
			        {
				        if($NotSeverity -contains "Unspecified") { $NotSeverity += "" } 
                        Write-Debug "Set post search criteria: NotSeverity = '$NotSeverity'"
				        If($NotSeverity -contains [String]$Update.MsrcSeverity)
				        {
					        Write-Debug "UpdateAccess: false"
					        $UpdateAccess = $false
				        } #End If $NotSeverity -contains $Update.MsrcSeverity
			        } #End If $NotSeverity -and $UpdateAccess -eq $true

			        If($MaxSize -and $UpdateAccess -eq $true)
			        {
                        Write-Debug "Set post search criteria: MaxDownloadSize <= '$MaxSize'"
				        If($MaxSize -le $Update.MaxDownloadSize)
				        {
					        Write-Debug "UpdateAccess: false"
					        $UpdateAccess = $false
				        } #End If $MaxSize -le $Update.MaxDownloadSize
			        } #End If $MaxSize -and $UpdateAccess -eq $true

			        If($MinSize -and $UpdateAccess -eq $true)
			        {
                        Write-Debug "Set post search criteria: MaxDownloadSize >= '$MinSize'"
				        If($MinSize -ge $Update.MaxDownloadSize)
				        {
					        Write-Debug "UpdateAccess: false"
					        $UpdateAccess = $false
				        } #End If $MinSize -ge $Update.MaxDownloadSize
			        } #End If $MinSize -and $UpdateAccess -eq $true
					
					If($IgnoreUserInput -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: CanRequestUserInput"
						If($Update.InstallationBehavior.CanRequestUserInput -eq $true)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.InstallationBehavior.CanRequestUserInput -eq $true
					} #End If $IgnoreUserInput -and $UpdateAccess -eq $true

					If($IgnoreRebootRequired -and $UpdateAccess -eq $true) 
					{
						Write-Debug "Set post search criteria: RebootBehavior"
						If($Update.InstallationBehavior.RebootBehavior -ne 0)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.InstallationBehavior.RebootBehavior -ne 0	
					} #End If $IgnoreRebootRequired -and $UpdateAccess -eq $true

					If($AutoSelectOnly -and $UpdateAccess -eq $true) 
					{
						Write-Debug "Set post search criteria: AutoSelectOnWebsites"
						If($Update.AutoSelectOnWebsites -ne $true)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End $Update.AutoSelectOnWebsites -ne $true
					} #End $AutoSelectOnly -and $UpdateAccess -eq $true

					If($UpdateAccess -eq $true)
					{
						Write-Debug "Convert size"
						Switch($Update.MaxDownloadSize)
						{
							{[System.Math]::Round($_/1KB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1KB,0))+" KB"; break }
							{[System.Math]::Round($_/1MB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1MB,0))+" MB"; break }  
							{[System.Math]::Round($_/1GB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1GB,0))+" GB"; break }    
							{[System.Math]::Round($_/1TB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1TB,0))+" TB"; break }
							default { $size = $_+"B" }
						} #End Switch
					
						Write-Debug "Convert KBArticleIDs"
						If($Update.KBArticleIDs -ne "")    
						{
							$KB = "KB"+$Update.KBArticleIDs
						} #End If $Update.KBArticleIDs -ne ""
						Else 
						{
							$KB = ""
						} #End Else $Update.KBArticleIDs -ne ""
						
						$Status = ""
				        If($Update.IsDownloaded)    {$Status += "D"} else {$status += "-"}
				        If($Update.IsInstalled)     {$Status += "I"} else {$status += "-"}
				        If($Update.IsMandatory)     {$Status += "M"} else {$status += "-"}
				        If($Update.IsHidden)        {$Status += "H"} else {$status += "-"}
				        If($Update.IsUninstallable) {$Status += "U"} else {$status += "-"}
				        If($Update.IsBeta)          {$Status += "B"} else {$status += "-"} 
		
						Add-Member -InputObject $Update -MemberType NoteProperty -Name ComputerName -Value $Computer -Force
						Add-Member -InputObject $Update -MemberType NoteProperty -Name KB -Value $KB -Force
						Add-Member -InputObject $Update -MemberType NoteProperty -Name Size -Value $size -Force
						Add-Member -InputObject $Update -MemberType NoteProperty -Name Status -Value $Status -Force
					
						$Update.PSTypeNames.Clear()
						$Update.PSTypeNames.Add('PSWindowsUpdate.WUList')
						$UpdateCollection += $Update
					} #End If $UpdateAccess -eq $true
					
					$NumberOfUpdate++
				} #End Foreach $Update in $objResults.Updates				
				Write-Progress -Activity "Post search updates for $Computer" -Status "Completed" -Completed
				
				$FoundUpdatesToDownload = $UpdateCollection.count
				Write-Verbose "Found [$FoundUpdatesToDownload] Updates in post search criteria"
				
				#################################
				# End STAGE 1: Get updates list #
				#################################
				
			} #End If Test-Connection -ComputerName $Computer -Quiet
		} #End Foreach $Computer in $ComputerName

		Return $UpdateCollection
		
	} #End Process
	
	End{}		
} #In The End :)

Function Get-WURebootStatus
{
    <#
	.SYNOPSIS
	    Show Windows Update Reboot status.

	.DESCRIPTION
	    Use Get-WURebootStatus to check if reboot is needed.
		
	.PARAMETER Silent
	    Get only status True/False without any more comments on screen. 
	
	.EXAMPLE
        Check whether restart is necessary. If yes, ask to do this or don't.
		
		PS C:\> Get-WURebootStatus
		Reboot is required. Do it now ? [Y/N]: Y
		
	.EXAMPLE
		Silent check whether restart is necessary. It return only status True or False without restart machine.
	
        PS C:\> Get-WURebootStatus -Silent
		True
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
        Get-WUInstallerStatus
	#>    

	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param
	(
		[Alias("StatusOnly")]
		[Switch]$Silent,
		[String[]]$ComputerName = "localhost",
		[Switch]$AutoReboot
	)
	
	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role
	}
	
	Process
	{
        ForEach($Computer in $ComputerName)
		{
			If ($pscmdlet.ShouldProcess($Computer,"Check that Windows update needs to restart system to install next updates")) 
			{				
				if($Env:COMPUTERNAME,"localhost","." -contains $Computer)
				{
				    Write-Verbose "$($Computer): Using WUAPI"
					$objSystemInfo= New-Object -ComObject "Microsoft.Update.SystemInfo"
					$RebootRequired = $objSystemInfo.RebootRequired
				} #End if $Computer -eq $Env:COMPUTERNAME
				else
				{
					Write-Verbose "$($Computer): Using Registry"
					$RegistryKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer) 
					$RegistrySubKey = $RegistryKey.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\") 
					$RegistrySubKeyNames = $RegistrySubKey.GetSubKeyNames() 
					$RebootRequired = $RegistrySubKeyNames -contains "RebootRequired" 

				} #End else $Computer -eq $Env:COMPUTERNAME
				
				Switch($RebootRequired)
				{
					$true	{
						If($Silent) 
						{
							Return $true
						} #End If $Silent
						Else 
						{
							if($AutoReboot -ne $true)
							{
								$Reboot = Read-Host "$($Computer): Reboot is required. Do it now ? [Y/N]"
							} #End If $AutoReboot -ne $true
							Else
							{
								$Reboot = "Y"
							} #End else $AutoReboot -ne $true
							
							If($Reboot -eq "Y")
							{
								Write-Verbose "Rebooting $($Computer)"
								Restart-Computer -ComputerName $Computer -Force
							} #End If $Reboot -eq "Y"
						} #End Else $Silent
					} #End Switch $true
						
					$false	{ 
						If($Silent) 
						{
							Return $false
						} #End If $Silent
						Else 
						{
							Write-Output "$($Computer): Reboot is not Required."
						} #End Else $Silent
					} #End Switch $false
				} #End Switch $objSystemInfo.RebootRequired
				
			} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Check that Windows update needs to restart system to install next updates")
		} #End ForEach $Computer in $ComputerName
	} #End Process
	
	End{}				
} #In The End :)

Function Get-WUServiceManager
{
	<#
	.SYNOPSIS
	    Show Service Manager configuration.

	.DESCRIPTION
	    Use Get-WUServiceManager to get available configuration of update services.
                              		
	.EXAMPLE
		Show currently available Windows Update Services on machine.
	
		PS C:\> Get-WUServiceManager

		ServiceID                            IsManaged IsDefault Name
		---------                            --------- --------- ----
		9482f4b4-e343-43b6-b170-9a65bc822c77 False     False     Windows Update
		7971f918-a847-4430-9279-4a52d1efe18d False     False     Microsoft Update
		3da21691-e39d-4da6-8a4b-b43877bcb1b7 True      True      Windows Server Update Service
		13df3d8f-78d7-4eb8-bb9c-2a101870d350 False     False     Offline Sync Service2
		a8f3b5e6-fb1f-4814-a047-2257d39c2460 False     False     Offline Sync Service

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
        Add-WUOfflineSync
        Remove-WUOfflineSync
	#>
	[OutputType('PSWindowsUpdate.WUServiceManager')]
	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="Low"
    )]
    Param()
	
	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role	
	}
	
	Process
	{
	    If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Get Windows Update ServiceManager")) 
		{
			$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"

			$ServiceManagerCollection = @()
	    	Foreach ($objService in $objServiceManager.Services) 
	    	{
				$objService.PSTypeNames.Clear()
				$objService.PSTypeNames.Add('PSWindowsUpdate.WUServiceManager')
						
				$ServiceManagerCollection += $objService
	    	} #End Foreach $objService in $objServiceManager.Services
			
			Return $ServiceManagerCollection
	    } #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Get Windows Update ServiceManager")		

	} #End Process
	
	End{}
} #In The End :)

Function Get-WUUninstall
{
    <#
	.SYNOPSIS
	    Uninstall update.

	.DESCRIPTION
	    Use Get-WUUninstall to uninstall update.
                              		
	.PARAM KBArticleID	
		Update ID that will be uninstalled.
	
	.EXAMPLE
        Try to uninstall update with specific KBArticleID = KB958830
		
		Get-WUUninstall -KBArticleID KB958830

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
        Get-WUInstall
        Get-WUList
	#>
	
	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="High"
    )]
    Param
    (
        [parameter(Mandatory=$true)]
		[Alias("HotFixID")]
		[String]$KBArticleID
    )

	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role	
	}
	
	Process
	{
	    If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Uninstall update $KBArticleID")) 
		{	    
			If($KBArticleID)
		    {
		        $KBArticleID = $KBArticleID -replace "KB", ""

		        wusa /uninstall /kb:$KBArticleID
		    } #End If $KBArticleID
		    Else
		    {
		        wmic qfe list
		    } #End Else $KBArticleID
			
		} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Uninstall update $KBArticleID")
	} #End Process
	
	End{}	
} #In The End :)

Function Hide-WUUpdate
{
	<#
	.SYNOPSIS
	    Get list of available updates meeting the criteria and try to hide/unhide it.

	.DESCRIPTION
	    Use Hide-WUUpdate to get list of available updates meeting specific criteria. In next step script try to hide (or unhide) updates.
		There are two types of filtering update: Pre search criteria, Post search criteria.
		- Pre search works on server side, like example: ( IsInstalled = 0 and IsHidden = 0 and CategoryIds contains '0fa1201d-4330-4fa8-8ae9-b877473b6441' )
		- Post search work on client side after downloading the pre-filtered list of updates, like example $KBArticleID -match $Update.KBArticleIDs

		Status list:
        D - IsDownloaded, I - IsInstalled, M - IsMandatory, H - IsHidden, U - IsUninstallable, B - IsBeta
		
	.PARAMETER UpdateType
		Pre search criteria. Finds updates of a specific type, such as 'Driver' and 'Software'. Default value contains all updates.

	.PARAMETER UpdateID
		Pre search criteria. Finds updates of a specific UUID (or sets of UUIDs), such as '12345678-9abc-def0-1234-56789abcdef0'.

	.PARAMETER RevisionNumber
		Pre search criteria. Finds updates of a specific RevisionNumber, such as '100'. This criterion must be combined with the UpdateID param.

	.PARAMETER CategoryIDs
		Pre search criteria. Finds updates that belong to a specified category (or sets of UUIDs), such as '0fa1201d-4330-4fa8-8ae9-b877473b6441'.

	.PARAMETER IsInstalled
		Pre search criteria. Finds updates that are installed on the destination computer.

	.PARAMETER IsHidden
		Pre search criteria. Finds updates that are marked as hidden on the destination computer.
	
	.PARAMETER IsNotHidden
		Pre search criteria. Finds updates that are not marked as hidden on the destination computer. Overwrite IsHidden param.
			
	.PARAMETER Criteria
		Pre search criteria. Set own string that specifies the search criteria.

	.PARAMETER ShowSearchCriteria
		Show choosen search criteria. Only works for pre search criteria.
		
	.PARAMETER Category
		Post search criteria. Finds updates that contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER KBArticleID
		Post search criteria. Finds updates that contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER Title
		Post search criteria. Finds updates that match part of title, such as ''

	.PARAMETER NotCategory
		Post search criteria. Finds updates that not contain a specified category name (or sets of categories name), such as 'Updates', 'Security Updates', 'Critical Updates', etc...
		
	.PARAMETER NotKBArticleID
		Post search criteria. Finds updates that not contain a KBArticleID (or sets of KBArticleIDs), such as 'KB982861'.
	
	.PARAMETER NotTitle
		Post search criteria. Finds updates that not match part of title.
		
	.PARAMETER IgnoreUserInput
		Post search criteria. Finds updates that the installation or uninstallation of an update can't prompt for user input.
	
	.PARAMETER IgnoreRebootRequired
		Post search criteria. Finds updates that specifies the restart behavior that not occurs when you install or uninstall the update.
	
	.PARAMETER ServiceID
		Set ServiceIS to change the default source of Windows Updates. It overwrite ServerSelection parameter value.

	.PARAMETER WindowsUpdate
		Set Windows Update Server as source. Default update config are taken from computer policy.
		
	.PARAMETER MicrosoftUpdate
		Set Microsoft Update Server as source. Default update config are taken from computer policy.

	.PARAMETER HideStatus
		Status used in script. Default is $True = hide update.
		
	.PARAMETER ComputerName	
	    Specify the name of the computer to the remote connection.

	.PARAMETER Debuger	
	    Debug mode.

	.EXAMPLE
		Get list of available updates from Microsoft Update Server and hide it.
	
		PS C:\> Hide-WUList -MicrosoftUpdate

		Confirm
		Are you sure you want to perform this action?
		Performing the operation "Hide Windows Malicious Software Removal Tool x64 - December 2013 (KB890830)?" on target
		"TEST".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		TEST         D--H-- KB890830    8 MB Windows Malicious Software Removal Tool x64 - December 2013 (KB890830)


	.EXAMPLE
		Unhide update
	
		PS C:\> Hide-WUUpdate -Title 'Windows Malicious*' -HideStatus:$false

		Confirm
		Are you sure you want to perform this action?
		Performing the operation "Unhide Windows Malicious Software Removal Tool x64 - December 2013 (KB890830)?" on target
		"TEST".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		ComputerName Status KB          Size Title
		------------ ------ --          ---- -----
		TEST         D----- KB890830    8 MB Windows Malicious Software Removal Tool x64 - December 2013 (KB890830)

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/


	.LINK
		Get-WUServiceManager
		Get-WUInstall
	#>

	[OutputType('PSWindowsUpdate.WUList')]
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]	
	Param
	(
		#Pre search criteria
		[ValidateSet("Driver", "Software")]
		[String]$UpdateType = "",
		[String[]]$UpdateID,
		[Int]$RevisionNumber,
		[String[]]$CategoryIDs,
		[Switch]$IsInstalled,
		[Switch]$IsHidden,
		[Switch]$IsNotHidden,
		[String]$Criteria,
		[Switch]$ShowSearchCriteria,		
		
		#Post search criteria
		[String[]]$Category="",
		[String[]]$KBArticleID,
		[String]$Title,
		
		[String[]]$NotCategory="",
		[String[]]$NotKBArticleID,
		[String]$NotTitle,	
		
		[Alias("Silent")]
		[Switch]$IgnoreUserInput,
		[Switch]$IgnoreRebootRequired,
		
		#Connection options
		[String]$ServiceID,
		[Switch]$WindowsUpdate,
		[Switch]$MicrosoftUpdate,
		[Switch]$HideStatus = $true,
		
		#Mode options
		[Switch]$Debuger,
		[parameter(ValueFromPipeline=$true,
			ValueFromPipelineByPropertyName=$true)]
		[String[]]$ComputerName
	)

	Begin
	{
		If($PSBoundParameters['Debuger'])
		{
			$DebugPreference = "Continue"
		} #End If $PSBoundParameters['Debuger']
		
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role	
	}

	Process
	{
		Write-Debug "STAGE 0: Prepare environment"
		######################################
		# Start STAGE 0: Prepare environment #
		######################################
		
		Write-Debug "Check if ComputerName in set"
		If($ComputerName -eq $null)
		{
			Write-Debug "Set ComputerName to localhost"
			[String[]]$ComputerName = $env:COMPUTERNAME
		} #End If $ComputerName -eq $null
		
		####################################			
		# End STAGE 0: Prepare environment #
		####################################
		
		$UpdateCollection = @()
		Foreach($Computer in $ComputerName)
		{
			If(Test-Connection -ComputerName $Computer -Quiet)
			{
				Write-Debug "STAGE 1: Get updates list"
				###################################
				# Start STAGE 1: Get updates list #
				###################################			

				If($Computer -eq $env:COMPUTERNAME)
				{
					Write-Debug "Create Microsoft.Update.ServiceManager object"
					$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager" #Support local instance only
					Write-Debug "Create Microsoft.Update.Session object for $Computer"
					$objSession = New-Object -ComObject "Microsoft.Update.Session" #Support local instance only
				} #End If $Computer -eq $env:COMPUTERNAME
				Else
				{
					Write-Debug "Create Microsoft.Update.Session object for $Computer"
					$objSession =  [activator]::CreateInstance([type]::GetTypeFromProgID("Microsoft.Update.Session",$Computer))
				} #End Else $Computer -eq $env:COMPUTERNAME
				
				Write-Debug "Create Microsoft.Update.Session.Searcher object for $Computer"
				$objSearcher = $objSession.CreateUpdateSearcher()

				If($WindowsUpdate)
				{
					Write-Debug "Set source of updates to Windows Update"
					$objSearcher.ServerSelection = 2
					$serviceName = "Windows Update"
				} #End If $WindowsUpdate
				ElseIf($MicrosoftUpdate)
				{
					Write-Debug "Set source of updates to Microsoft Update"
					$serviceName = $null
					Foreach ($objService in $objServiceManager.Services) 
					{
						If($objService.Name -eq "Microsoft Update")
						{
							$objSearcher.ServerSelection = 3
							$objSearcher.ServiceID = $objService.ServiceID
							$serviceName = $objService.Name
							Break
						}#End If $objService.Name -eq "Microsoft Update"
					}#End ForEach $objService in $objServiceManager.Services
					
					If(-not $serviceName)
					{
						Write-Warning "Can't find registered service Microsoft Update. Use Get-WUServiceManager to get registered service."
						Return
					}#Enf If -not $serviceName
				} #End Else $WindowsUpdate If $MicrosoftUpdate
				ElseIf($Computer -eq $env:COMPUTERNAME) #Support local instance only
				{
					Foreach ($objService in $objServiceManager.Services) 
					{
						If($ServiceID)
						{
							If($objService.ServiceID -eq $ServiceID)
							{
								$objSearcher.ServiceID = $ServiceID
								$objSearcher.ServerSelection = 3
								$serviceName = $objService.Name
								Break
							} #End If $objService.ServiceID -eq $ServiceID
						} #End If $ServiceID
						Else
						{
							If($objService.IsDefaultAUService -eq $True)
							{
								$serviceName = $objService.Name
								Break
							} #End If $objService.IsDefaultAUService -eq $True
						} #End Else $ServiceID
					} #End Foreach $objService in $objServiceManager.Services
				} #End Else $MicrosoftUpdate If $Computer -eq $env:COMPUTERNAME
				ElseIf($ServiceID)
				{
					$objSearcher.ServiceID = $ServiceID
					$objSearcher.ServerSelection = 3
					$serviceName = $ServiceID
				}
				Else #End Else $Computer -eq $env:COMPUTERNAME If $ServiceID
				{
					$serviceName = "default (for $Computer) Windows Update"
				} #End Else $ServiceID
				Write-Debug "Set source of updates to $serviceName"
				
				Write-Verbose "Connecting to $serviceName server. Please wait..."
				Try
				{
					$search = ""
					If($Criteria)
					{
						$search = $Criteria
					} #End If $Criteria
					Else
					{
						If($IsInstalled) 
						{
							$search = "IsInstalled = 1"
							Write-Debug "Set pre search criteria: IsInstalled = 1"
						} #End If $IsInstalled
						Else
						{
							$search = "IsInstalled = 0"	
							Write-Debug "Set pre search criteria: IsInstalled = 0"
						} #End Else $IsInstalled
						
						If($UpdateType -ne "")
						{
							Write-Debug "Set pre search criteria: Type = $UpdateType"
							$search += " and Type = '$UpdateType'"
						} #End If $UpdateType -ne ""					
						
						If($UpdateID)
						{
							Write-Debug "Set pre search criteria: UpdateID = '$([string]::join(", ", $UpdateID))'"
							$tmp = $search
							$search = ""
							$LoopCount = 0
							Foreach($ID in $UpdateID)
							{
								If($LoopCount -gt 0)
								{
									$search += " or "
								} #End If $LoopCount -gt 0
								If($RevisionNumber)
								{
									Write-Debug "Set pre search criteria: RevisionNumber = '$RevisionNumber'"	
									$search += "($tmp and UpdateID = '$ID' and RevisionNumber = $RevisionNumber)"
								} #End If $RevisionNumber
								Else
								{
									$search += "($tmp and UpdateID = '$ID')"
								} #End Else $RevisionNumber
								$LoopCount++
							} #End Foreach $ID in $UpdateID
						} #End If $UpdateID

						If($CategoryIDs)
						{
							Write-Debug "Set pre search criteria: CategoryIDs = '$([string]::join(", ", $CategoryIDs))'"
							$tmp = $search
							$search = ""
							$LoopCount =0
							Foreach($ID in $CategoryIDs)
							{
								If($LoopCount -gt 0)
								{
									$search += " or "
								} #End If $LoopCount -gt 0
								$search += "($tmp and CategoryIDs contains '$ID')"
								$LoopCount++
							} #End Foreach $ID in $CategoryIDs
						} #End If $CategoryIDs
						
						If($IsNotHidden) 
						{
							Write-Debug "Set pre search criteria: IsHidden = 0"
							$search += " and IsHidden = 0"	
						} #End If $IsNotHidden
						ElseIf($IsHidden) 
						{
							Write-Debug "Set pre search criteria: IsHidden = 1"
							$search += " and IsHidden = 1"	
						} #End ElseIf $IsHidden

						#Don't know why every update have RebootRequired=false which is not always true
						If($IgnoreRebootRequired) 
						{
							Write-Debug "Set pre search criteria: RebootRequired = 0"
							$search += " and RebootRequired = 0"	
						} #End If $IgnoreRebootRequired
					} #End Else $Criteria
					
					Write-Debug "Search criteria is: $search"
					
					If($ShowSearchCriteria)
					{
						Write-Output $search
					} #End If $ShowSearchCriteria
			
					$objResults = $objSearcher.Search($search)
				} #End Try
				Catch
				{
					If($_ -match "HRESULT: 0x80072EE2")
					{
						Write-Warning "Probably you don't have connection to Windows Update server"
					} #End If $_ -match "HRESULT: 0x80072EE2"
					Return
				} #End Catch

				$NumberOfUpdate = 1
				$PreFoundUpdatesToDownload = $objResults.Updates.count
				Write-Verbose "Found [$PreFoundUpdatesToDownload] Updates in pre search criteria"				
				
				If($PreFoundUpdatesToDownload -eq 0)
				{
					Continue
				} #End If $PreFoundUpdatesToDownload -eq 0 
				
				Foreach($Update in $objResults.Updates)
				{	
					$UpdateAccess = $true
					Write-Progress -Activity "Post search updates for $Computer" -Status "[$NumberOfUpdate/$PreFoundUpdatesToDownload] $($Update.Title) $size" -PercentComplete ([int]($NumberOfUpdate/$PreFoundUpdatesToDownload * 100))
					Write-Debug "Set post search criteria: $($Update.Title)"
					
					If($Category -ne "")
					{
						$UpdateCategories = $Update.Categories | Select-Object Name
						Write-Debug "Set post search criteria: Categories = '$([string]::join(", ", $Category))'"	
						Foreach($Cat in $Category)
						{
							If(!($UpdateCategories -match $Cat))
							{
								Write-Debug "UpdateAccess: false"
								$UpdateAccess = $false
							} #End If !($UpdateCategories -match $Cat)
							Else
							{
								$UpdateAccess = $true
								Break
							} #End Else !($UpdateCategories -match $Cat)
						} #End Foreach $Cat in $Category	
					} #End If $Category -ne ""

					If($NotCategory -ne "" -and $UpdateAccess -eq $true)
					{
						$UpdateCategories = $Update.Categories | Select-Object Name
						Write-Debug "Set post search criteria: NotCategories = '$([string]::join(", ", $NotCategory))'"	
						Foreach($Cat in $NotCategory)
						{
							If($UpdateCategories -match $Cat)
							{
								Write-Debug "UpdateAccess: false"
								$UpdateAccess = $false
								Break
							} #End If $UpdateCategories -match $Cat
						} #End Foreach $Cat in $NotCategory	
					} #End If $NotCategory -ne "" -and $UpdateAccess -eq $true					
					
					If($KBArticleID -ne $null -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: KBArticleIDs = '$([string]::join(", ", $KBArticleID))'"
						If(!($KBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs))
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If !($KBArticleID -match $Update.KBArticleIDs)								
					} #End If $KBArticleID -ne $null -and $UpdateAccess -eq $true

					If($NotKBArticleID -ne $null -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: NotKBArticleIDs = '$([string]::join(", ", $NotKBArticleID))'"
						If($NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If$NotKBArticleID -match $Update.KBArticleIDs -and "" -ne $Update.KBArticleIDs					
					} #End If $NotKBArticleID -ne $null -and $UpdateAccess -eq $true
					
					If($Title -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: Title = '$Title'"
						If($Update.Title -notmatch $Title)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.Title -notmatch $Title
					} #End If $Title -and $UpdateAccess -eq $true

					If($NotTitle -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: NotTitle = '$NotTitle'"
						If($Update.Title -match $NotTitle)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.Title -notmatch $NotTitle
					} #End If $NotTitle -and $UpdateAccess -eq $true
					
					If($IgnoreUserInput -and $UpdateAccess -eq $true)
					{
						Write-Debug "Set post search criteria: CanRequestUserInput"
						If($Update.InstallationBehavior.CanRequestUserInput -eq $true)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.InstallationBehavior.CanRequestUserInput -eq $true
					} #End If $IgnoreUserInput -and $UpdateAccess -eq $true

					If($IgnoreRebootRequired -and $UpdateAccess -eq $true) 
					{
						Write-Debug "Set post search criteria: RebootBehavior"
						If($Update.InstallationBehavior.RebootBehavior -ne 0)
						{
							Write-Debug "UpdateAccess: false"
							$UpdateAccess = $false
						} #End If $Update.InstallationBehavior.RebootBehavior -ne 0	
					} #End If $IgnoreRebootRequired -and $UpdateAccess -eq $true

					If($UpdateAccess -eq $true)
					{
						Write-Debug "Convert size"
						Switch($Update.MaxDownloadSize)
						{
							{[System.Math]::Round($_/1KB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1KB,0))+" KB"; break }
							{[System.Math]::Round($_/1MB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1MB,0))+" MB"; break }  
							{[System.Math]::Round($_/1GB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1GB,0))+" GB"; break }    
							{[System.Math]::Round($_/1TB,0) -lt 1024} { $size = [String]([System.Math]::Round($_/1TB,0))+" TB"; break }
							default { $size = $_+"B" }
						} #End Switch
					
						Write-Debug "Convert KBArticleIDs"
						If($Update.KBArticleIDs -ne "")    
						{
							$KB = "KB"+$Update.KBArticleIDs
						} #End If $Update.KBArticleIDs -ne ""
						Else 
						{
							$KB = ""
						} #End Else $Update.KBArticleIDs -ne ""
						
						if($Update.IsHidden -ne $HideStatus)
						{
							if($HideStatus)
							{
								$StatusName = "Hide"
							} #$HideStatus
							else
							{
								$StatusName = "Unhide"
							} #Else $HideStatus
							
							If($pscmdlet.ShouldProcess($Computer,"$StatusName $($Update.Title)?")) 
							{
								Try
								{
									$Update.IsHidden = $HideStatus
								}
								Catch
								{
									Write-Warning "You haven't privileges to make this. Try start an eleated Windows PowerShell console."
								}
								
							} #$pscmdlet.ShouldProcess($Computer,"Hide $($Update.Title)?")
						} #End $Update.IsHidden -ne $HideStatus
						
						$Status = ""
				        If($Update.IsDownloaded)    {$Status += "D"} else {$status += "-"}
				        If($Update.IsInstalled)     {$Status += "I"} else {$status += "-"}
				        If($Update.IsMandatory)     {$Status += "M"} else {$status += "-"}
				        If($Update.IsHidden)        {$Status += "H"} else {$status += "-"}
				        If($Update.IsUninstallable) {$Status += "U"} else {$status += "-"}
				        If($Update.IsBeta)          {$Status += "B"} else {$status += "-"} 
		
						Add-Member -InputObject $Update -MemberType NoteProperty -Name ComputerName -Value $Computer
						Add-Member -InputObject $Update -MemberType NoteProperty -Name KB -Value $KB
						Add-Member -InputObject $Update -MemberType NoteProperty -Name Size -Value $size
						Add-Member -InputObject $Update -MemberType NoteProperty -Name Status -Value $Status
					
						$Update.PSTypeNames.Clear()
						$Update.PSTypeNames.Add('PSWindowsUpdate.WUList')
						$UpdateCollection += $Update
					} #End If $UpdateAccess -eq $true
					
					$NumberOfUpdate++
				} #End Foreach $Update in $objResults.Updates				
				Write-Progress -Activity "Post search updates for $Computer" -Status "Completed" -Completed
				
				$FoundUpdatesToDownload = $UpdateCollection.count
				Write-Verbose "Found [$FoundUpdatesToDownload] Updates in post search criteria"
				
				#################################
				# End STAGE 1: Get updates list #
				#################################
				
			} #End If Test-Connection -ComputerName $Computer -Quiet
		} #End Foreach $Computer in $ComputerName

		Return $UpdateCollection
		
	} #End Process
	
	End{}		
} #In The End :)

Function Invoke-WUInstall
{
	<#
	.SYNOPSIS
		Invoke Get-WUInstall remotely.

	.DESCRIPTION
		Use Invoke-WUInstall to invoke Windows Update install remotly. It Based on TaskScheduler because 
		CreateUpdateDownloader() and CreateUpdateInstaller() methods can't be called from a remote computer - E_ACCESSDENIED.
		
		Note:
		Because we do not have the ability to interact, is recommended use -AcceptAll with WUInstall filters in script block.
	
	.PARAMETER ComputerName
		Specify computer name.

	.PARAMETER TaskName
		Specify task name. Default is PSWindowsUpdate.
		
	.PARAMETER Script
		Specify PowerShell script block that you what to run. Default is {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll | Out-File C:\PSWindowsUpdate.log}
		
	.EXAMPLE
		PS C:\> $Script = {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll -AutoReboot | Out-File C:\PSWindowsUpdate.log}
		PS C:\> Invoke-WUInstall -ComputerName pc1.contoso.com -Script $Script
		...
		PS C:\> Get-Content \\pc1.contoso.com\c$\PSWindowsUpdate.log
		
	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/

	.LINK
		Get-WUInstall
	#>
	[CmdletBinding(
		SupportsShouldProcess=$True,
		ConfirmImpact="High"
	)]
	param
	(
		[Parameter(ValueFromPipeline=$True,
					ValueFromPipelineByPropertyName=$True)]
		[String[]]$ComputerName,
		[String]$TaskName = "PSWindowsUpdate",
		[ScriptBlock]$Script = {ipmo PSWindowsUpdate; Get-WUInstall -AcceptAll | Out-File C:\PSWindowsUpdate.log},
		[Switch]$OnlineUpdate
	)

	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role
		
		$PSWUModule = Get-Module -Name PSWindowsUpdate -ListAvailable
		
		Write-Verbose "Create schedule service object"
		$Scheduler = New-Object -ComObject Schedule.Service
			
		$Task = $Scheduler.NewTask(0)

		$RegistrationInfo = $Task.RegistrationInfo
		$RegistrationInfo.Description = $TaskName
		$RegistrationInfo.Author = $User.Name

		$Settings = $Task.Settings
		$Settings.Enabled = $True
		$Settings.StartWhenAvailable = $True
		$Settings.Hidden = $False

		$Action = $Task.Actions.Create(0)
		$Action.Path = "powershell"
		$Action.Arguments = "-Command $Script"
		
		$Task.Principal.RunLevel = 1	
	}
	
	Process
	{
		ForEach($Computer in $ComputerName)
		{
			If ($pscmdlet.ShouldProcess($Computer,"Invoke WUInstall")) 
			{
				if(Test-Connection -ComputerName $Computer -Quiet)
				{
					Write-Verbose "Check PSWindowsUpdate module on $Computer"
					Try
					{
						$ModuleTest = Invoke-Command -ComputerName $Computer -ScriptBlock {Get-Module -ListAvailable -Name PSWindowsUpdate} -ErrorAction Stop
					} #End Try
					Catch
					{
						Write-Warning "Can't access to machine $Computer. Try use: winrm qc"
						Continue
					} #End Catch
					$ModulStatus = $false
					
					if($ModuleTest -eq $null -or $ModuleTest.Version -lt $PSWUModule.Version)
					{
						if($OnlineUpdate)
						{
							Update-WUModule -ComputerName $Computer
						} #End If $OnlineUpdate
						else
						{
							Update-WUModule -ComputerName $Computer	-LocalPSWUSource (Get-Module -ListAvailable -Name PSWindowsUpdate).ModuleBase
						} #End Else $OnlineUpdate
					} #End If $ModuleTest -eq $null -or $ModuleTest.Version -lt $PSWUModule.Version
					
					#Sometimes can't connect at first time
					$Info = "Connect to scheduler and register task on $Computer"
					for ($i=1; $i -le 3; $i++)
					{
						$Info += "."
						Write-Verbose $Info
						Try
						{
							$Scheduler.Connect($Computer)
							Break
						} #End Try
						Catch
						{
							if($i -ge 3)
							{
								Write-Error "Can't connect to Schedule service on $Computer" -ErrorAction Stop
							} #End If $i -ge 3
							else
							{
								sleep -Seconds 1
							} #End Else $i -ge 3
						} #End Catch					
					} #End For $i=1; $i -le 3; $i++
					
					$RootFolder = $Scheduler.GetFolder("\")
					$SendFlag = 1
					if($Scheduler.GetRunningTasks(0) | Where-Object {$_.Name -eq $TaskName})
					{
						$CurrentTask = $RootFolder.GetTask($TaskName)
						$Title = "Task $TaskName is curretly running: $($CurrentTask.Definition.Actions | Select-Object -exp Path) $($CurrentTask.Definition.Actions | Select-Object -exp Arguments)"
						$Message = "What do you want to do?"

						$ChoiceContiniue = New-Object System.Management.Automation.Host.ChoiceDescription "&Continue Current Task"
						$ChoiceStart = New-Object System.Management.Automation.Host.ChoiceDescription "Stop and Start &New Task"
						$ChoiceStop = New-Object System.Management.Automation.Host.ChoiceDescription "&Stop Task"
						$Options = [System.Management.Automation.Host.ChoiceDescription[]]($ChoiceContiniue, $ChoiceStart, $ChoiceStop)
						$SendFlag = $host.ui.PromptForChoice($Title, $Message, $Options, 0)
					
						if($SendFlag -ge 1)
						{
							($RootFolder.GetTask($TaskName)).Stop(0)
						} #End If $SendFlag -eq 1	
						
					} #End If !($Scheduler.GetRunningTasks(0) | Where-Object {$_.Name -eq $TaskName})
						
					if($SendFlag -eq 1)
					{
						$RootFolder.RegisterTaskDefinition($TaskName, $Task, 6, "SYSTEM", $Null, 1) | Out-Null
						$RootFolder.GetTask($TaskName).Run(0) | Out-Null
					} #End If $SendFlag -eq 1
					
					#$RootFolder.DeleteTask($TaskName,0)
				} #End If Test-Connection -ComputerName $Computer -Quiet
				else
				{
					Write-Warning "Machine $Computer is not responding."
				} #End Else Test-Connection -ComputerName $Computer -Quiet
			} #End If $pscmdlet.ShouldProcess($Computer,"Invoke WUInstall")
		} #End ForEach $Computer in $ComputerName
		Write-Verbose "Invoke-WUInstall complete."
	}
	
	End {}

}

Function Remove-WUOfflineSync
{
    <#
	.SYNOPSIS
	    Unregister offline scaner service.

	.DESCRIPTION
	    Use Remove-WUOfflineSync to unregister Windows Update offline scan file (wsusscan.cab or wsusscn2.cab) from current machine.
                              		
	.EXAMPLE
		Check if Offline Sync Service is registered and try unregister it.
	
		PS C:\> Remove-WUOfflineSync

		Confirm
		Are you sure you want to perform this action?
		Performing operation "Unregister Windows Update offline scan file" on Target "G1".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

		ServiceID                            IsManaged IsDefault Name
		---------                            --------- --------- ----
		9482f4b4-e343-43b6-b170-9a65bc822c77 False     False     Windows Update
		7971f918-a847-4430-9279-4a52d1efe18d False     False     Microsoft Update
		3da21691-e39d-4da6-8a4b-b43877bcb1b7 True      True      Windows Server Update Service

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc

	.LINK
        Get-WUServiceManager
        Add-WUOfflineSync
	#>

	[CmdletBinding(
    	SupportsShouldProcess=$True,
        ConfirmImpact="High"
    )]
    Param()
	
	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role	
	}
	
	Process
	{
	    $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
	    
		$State = 1
	    Foreach ($objService in $objServiceManager.Services) 
	    {
	        If($objService.Name -eq "Offline Sync Service")
	        {
	           	If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Unregister Windows Update offline scan file")) 
				{
					Try
					{
						$objServiceManager.RemoveService($objService.ServiceID)
					} #End Try
					Catch
					{
			            If($_ -match "HRESULT: 0x80070005")
			            {
			                Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
			            } #End If $_ -match "HRESULT: 0x80070005"
						Else
						{
							Write-Error $_
						} #End Else $_ -match "HRESULT: 0x80070005"
						
			            Return
					} #End Catch
	            } #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Unregister Windows Update offline scan file")
				
				Get-WUServiceManager
	            $State = 0;    
				
	        } #End If $objService.Name -eq "Offline Sync Service"
	    } #End Foreach $objService in $objServiceManager.Services
	    
	    If($State)
	    {
	        Write-Warning "Offline Sync Service don't exist on current machine."
	    } #End If $State
	} #End Process
	
	End{}
} #In The End :)

Function Remove-WUServiceManager 
{
	<#
	.SYNOPSIS
	    Remove windows update service manager.

	.DESCRIPTION
	    Use Remove-WUServiceManager to unregister Windows Update Service Manager.
    
	.PARAMETER ServiceID	
		An identifier for the service to be unregistered.
	
	.EXAMPLE
		Try unregister Microsoft Update Service.
	
		PS H:\> Remove-WUServiceManager -ServiceID "7971f918-a847-4430-9279-4a52d1efe18d"

		Confirm
		Are you sure you want to perform this action?
		Performing the operation "Unregister Windows Update Service Manager: 7971f918-a847-4430-9279-4a52d1efe18d" on target "MG".
		[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): Y

	.NOTES
		Author: Michal Gajda
		Blog  : http://commandlinegeeks.com/
		
	.LINK
		http://gallery.technet.microsoft.com/scriptcenter/2d191bcd-3308-4edd-9de2-88dff796b0bc
	
	.LINK
		http://msdn.microsoft.com/en-us/library/aa387290(v=vs.85).aspx
		http://support.microsoft.com/kb/926464

	.LINK
        Get-WUServiceManager
		Add-WUServiceManager
	#>
    [OutputType('PSWindowsUpdate.WUServiceManager')]
	[CmdletBinding(
        SupportsShouldProcess=$True,
        ConfirmImpact="High"
    )]
    Param
    (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceID
    )

	Begin
	{
		$User = [Security.Principal.WindowsIdentity]::GetCurrent()
		$Role = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

		if(!$Role)
		{
			Write-Warning "To perform some operations you must run an elevated Windows PowerShell console."	
		} #End If !$Role		
	}
	
    Process
	{
        $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
        Try
        {
            If ($pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Unregister Windows Update Service Manager: $ServiceID")) 
			{
				$objService = $objServiceManager.RemoveService($ServiceID)
				
			} #End If $pscmdlet.ShouldProcess($Env:COMPUTERNAME,"Unregister Windows Update Service Manager: $ServiceID"
        } #End Try
        Catch 
        {
            If($_ -match "HRESULT: 0x80070005")
            {
                Write-Warning "Your security policy don't allow a non-administator identity to perform this task"
            } #End If $_ -match "HRESULT: 0x80070005"
			Else
			{
				Write-Error $_
			} #End Else $_ -match "HRESULT: 0x80070005"
			
            Return
        } #End Catch
		
        Return $objService	
	} #End Process

	End{}
} #In The End :)

Get-WUInstall -updatetype Software -IgnoreReboot -AcceptAll
#-MicrosoftUpdate # -listonly