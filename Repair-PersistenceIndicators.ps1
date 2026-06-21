[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string[]]$DisableScheduledTask,
    [string[]]$DisableService,
    [string[]]$RemoveStartupValue,
    [switch]$CreateRestorePoint,
    [string]$OutputPath="$env:USERPROFILE\Desktop\PersistenceRepair"
)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
$Log=Join-Path $OutputPath ("repair-{0:yyyyMMdd-HHmmss}.log"-f(Get-Date))
function L($m){"$(Get-Date -Format s) $m"|Tee-Object -FilePath $Log -Append}
if(-not($DisableScheduledTask-or$DisableService-or$RemoveStartupValue)){throw'Choose at least one remediation action.'}
Get-ScheduledTask|Select TaskPath,TaskName,State|Export-Csv (Join-Path $OutputPath 'tasks-before.csv') -NoTypeInformation
Get-CimInstance Win32_StartupCommand|Select Name,Command,Location,User|Export-Csv (Join-Path $OutputPath 'startup-before.csv') -NoTypeInformation
if($CreateRestorePoint-and(Get-Command Checkpoint-Computer -ErrorAction SilentlyContinue)){Checkpoint-Computer -Description 'Before persistence remediation' -RestorePointType MODIFY_SETTINGS -ErrorAction SilentlyContinue}
foreach($id in $DisableScheduledTask){
    $parts=$id -split '\\',2
    $task=Get-ScheduledTask -TaskName $parts[-1] -ErrorAction Stop
    if($PSCmdlet.ShouldProcess($id,'Disable scheduled task')){Disable-ScheduledTask -InputObject $task|Out-Null;L"Disabled task $id"}
}
foreach($s in $DisableService){
    $svc=Get-Service $s -ErrorAction Stop
    if($svc.Name-in @('WinDefend','EventLog','RpcSs','SamSs','LanmanWorkstation','Dnscache')){throw"Refusing protected core service: $s"}
    if($PSCmdlet.ShouldProcess($s,'Stop and disable service')){Stop-Service $s -Force -ErrorAction SilentlyContinue;Set-Service $s -StartupType Disabled;L"Disabled service $s"}
}
foreach($item in $RemoveStartupValue){
    $parts=$item -split '\|',2
    if($parts.Count-ne2){throw"Startup value format must be RegistryPath|ValueName: $item"}
    $path=$parts[0];$name=$parts[1]
    if($path-notmatch '^HK(CU|LM):\\Software\\Microsoft\\Windows\\CurrentVersion\\Run(Once)?$'){throw"Unsupported startup registry path: $path"}
    if(Test-Path $path){Get-ItemProperty $path|Out-File (Join-Path $OutputPath (($name-replace '[^A-Za-z0-9_-]','_')+'.backup.txt'));if($PSCmdlet.ShouldProcess("$path\$name",'Remove startup value')){Remove-ItemProperty -Path $path -Name $name -ErrorAction Stop;L"Removed startup value $name"}}
}
Get-ScheduledTask|Select TaskPath,TaskName,State|Export-Csv (Join-Path $OutputPath 'tasks-after.csv') -NoTypeInformation
L'Remediation workflow finished.'
