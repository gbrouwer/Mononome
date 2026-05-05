# Norns Sync

This project keeps norns code in the local `code/` folder and syncs it to:

```text
/home/we/dust/code
```

Defaults:

```text
host: norns.local
user: we
remote: /home/we/dust/code
```

Override them from PowerShell when needed:

```powershell
.\tools\norns-pull.ps1 -HostName 192.168.1.50 -User we -RemoteCodeDir /home/we/dust/code
.\tools\norns-push.ps1 -HostName 192.168.1.50 -User we -RemoteCodeDir /home/we/dust/code
```

The scripts copy files; they do not delete old files on either side. Remove retired instruments manually after confirming they are no longer needed.
