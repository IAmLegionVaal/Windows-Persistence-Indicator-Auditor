# Windows Persistence Indicator Auditor

A defensive, read-only PowerShell toolkit for inventorying common Windows startup and persistence locations.

## Coverage

- Startup commands
- Run and RunOnce registry locations
- Scheduled tasks
- Auto-start services
- Startup folders
- WMI event subscriptions where available
- Digital-signature context for referenced files

## Run

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\Windows_Persistence_Indicator_Auditor.ps1
```

## Output

CSV inventories, JSON evidence, and an HTML review report.

## Safety

Read-only reporting. The toolkit does not disable, remove, or alter startup items.
