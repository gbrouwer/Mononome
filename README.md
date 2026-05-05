# Mononome

Local project for norns shield Lua instruments.

The repository mirrors norns scripts under `code/`, matching the device folder:

```text
C:\Core\Mononome\code        ->        we@norns.local:/home/we/dust/code
```

## First-time SSH setup

Install this PC's SSH public key on the norns once:

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh we@norns.local "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Enter the norns password when prompted. On a stock norns this is commonly `sleep`, unless it has been changed.

Then test access:

```powershell
ssh we@norns.local "hostname && ls /home/we/dust/code"
```

## Sync

Pull all scripts from the norns into `code/`:

```powershell
.\tools\norns-pull.ps1
```

Push all local scripts in `code/` back to the norns:

```powershell
.\tools\norns-push.ps1
```

Pull or push one script folder/file:

```powershell
.\tools\norns-pull.ps1 -Name my_instrument
.\tools\norns-push.ps1 -Name my_instrument
```

The VS Code SFTP config in `.vscode/sftp.json` points at the same remote folder.
It is configured with the default norns login (`we` / `sleep`).

## Clone Decipher

Create a renamed copy of `decipher`:

```powershell
.\tools\clone-decipher.ps1 -Name desolution
```

The helper copies the full instrument folder, renames the main Lua file and internal library folder, and rewrites `decipher` references and sample paths to the new name.
