#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputPath)

$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Persistence_Indicator_Reports'}
New-Item -Path $OutputPath -ItemType Directory -Force|Out-Null

$startup=Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue|Select-Object Name,Command,Location,User

$runKeys=@(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
)
$registryItems=[System.Collections.Generic.List[object]]::new()
foreach($key in $runKeys){
    if(Test-Path $key){
        $item=Get-ItemProperty $key -ErrorAction SilentlyContinue
        foreach($property in $item.PSObject.Properties|Where-Object{$_.Name -notmatch '^PS'}){
            $registryItems.Add([PSCustomObject]@{RegistryPath=$key;Name=$property.Name;Value=[string]$property.Value})
        }
    }
}

$tasks=Get-ScheduledTask -ErrorAction SilentlyContinue|Where-Object{$_.State -ne 'Disabled'}|ForEach-Object{
    $info=$_|Get-ScheduledTaskInfo -ErrorAction SilentlyContinue
    [PSCustomObject]@{
        TaskName=$_.TaskName
        TaskPath=$_.TaskPath
        State=$_.State
        Author=$_.Author
        LastRunTime=$info.LastRunTime
        NextRunTime=$info.NextRunTime
        Actions=(($_.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"}) -join '; ')
    }
}

$services=Get-CimInstance Win32_Service -ErrorAction SilentlyContinue|Where-Object{$_.StartMode -eq 'Auto'}|Select-Object Name,DisplayName,State,StartMode,StartName,PathName

$startupFolders=@(
    [Environment]::GetFolderPath('Startup'),
    [Environment]::GetFolderPath('CommonStartup')
)
$folderItems=foreach($folder in $startupFolders){
    if(Test-Path $folder){Get-ChildItem $folder -Force -ErrorAction SilentlyContinue|Select-Object @{n='Folder';e={$folder}},Name,FullName,Length,CreationTime,LastWriteTime}
}

$wmiFilters=Get-CimInstance -Namespace root\subscription -ClassName __EventFilter -ErrorAction SilentlyContinue|Select-Object Name,EventNamespace,Query,QueryLanguage
$wmiConsumers=Get-CimInstance -Namespace root\subscription -ClassName CommandLineEventConsumer -ErrorAction SilentlyContinue|Select-Object Name,CommandLineTemplate,ExecutablePath
$wmiBindings=Get-CimInstance -Namespace root\subscription -ClassName __FilterToConsumerBinding -ErrorAction SilentlyContinue|Select-Object Filter,Consumer

$summary=[PSCustomObject]@{
    Computer=$env:COMPUTERNAME
    StartupCommands=@($startup).Count
    RegistryRunItems=@($registryItems).Count
    EnabledScheduledTasks=@($tasks).Count
    AutoStartServices=@($services).Count
    StartupFolderItems=@($folderItems).Count
    WmiFilters=@($wmiFilters).Count
    WmiConsumers=@($wmiConsumers).Count
    Generated=Get-Date
}

$startup|Export-Csv (Join-Path $OutputPath "startup_commands_$stamp.csv") -NoTypeInformation -Encoding UTF8
$registryItems|Export-Csv (Join-Path $OutputPath "registry_run_items_$stamp.csv") -NoTypeInformation -Encoding UTF8
$tasks|Export-Csv (Join-Path $OutputPath "scheduled_tasks_$stamp.csv") -NoTypeInformation -Encoding UTF8
$services|Export-Csv (Join-Path $OutputPath "auto_start_services_$stamp.csv") -NoTypeInformation -Encoding UTF8
$folderItems|Export-Csv (Join-Path $OutputPath "startup_folder_items_$stamp.csv") -NoTypeInformation -Encoding UTF8
$wmiFilters|Export-Csv (Join-Path $OutputPath "wmi_event_filters_$stamp.csv") -NoTypeInformation -Encoding UTF8
$wmiConsumers|Export-Csv (Join-Path $OutputPath "wmi_event_consumers_$stamp.csv") -NoTypeInformation -Encoding UTF8
$wmiBindings|Export-Csv (Join-Path $OutputPath "wmi_event_bindings_$stamp.csv") -NoTypeInformation -Encoding UTF8

@{Summary=$summary;StartupCommands=$startup;RegistryRunItems=$registryItems;ScheduledTasks=$tasks;AutoStartServices=$services;StartupFolderItems=$folderItems;WmiFilters=$wmiFilters;WmiConsumers=$wmiConsumers;WmiBindings=$wmiBindings}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $OutputPath "persistence_indicators_$stamp.json") -Encoding UTF8

$html="<h1>Windows Persistence Indicator Audit - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Registry Run Items</h2>$($registryItems|ConvertTo-Html -Fragment)<h2>Startup Commands</h2>$($startup|ConvertTo-Html -Fragment)<h2>Scheduled Tasks</h2>$($tasks|Select-Object -First 200|ConvertTo-Html -Fragment)<h2>Auto-start Services</h2>$($services|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Windows Persistence Indicator Audit'|Set-Content (Join-Path $OutputPath "persistence_indicators_$stamp.html") -Encoding UTF8
$summary|Format-List
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
