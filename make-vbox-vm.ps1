# Turn the built disk.img into a VirtualBox VM.
#
#   powershell -ExecutionPolicy Bypass -File .\make-vbox-vm.ps1
#
# VirtualBox cannot attach a raw .img, so this converts it to a dynamically
# allocated VDI first — which also shrinks it, because only the used blocks are
# stored. Then it creates the VM, wires up the disk, and picks settings that
# match what the kernel in this image actually has drivers for.

param(
    [string]$VMName   = "master-penguin-linux",
    [string]$ImgPath  = "G:\VirtualDisk\master-penguin-linux.img",
    [string]$VMFolder = "G:\VirtualDisk",
    [int]   $MemoryMB = 2048,
    [int]   $CPUs     = 4,
    [switch]$Replace,
    [switch]$Start
)

$ErrorActionPreference = "Stop"

$VBoxManage = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBoxManage)) {
    throw "VBoxManage not found at $VBoxManage — is VirtualBox installed?"
}

if (-not (Test-Path $ImgPath)) {
    throw @"
disk image not found: $ImgPath

The build lives inside WSL. Copy it out with cp — not a PowerShell redirect,
which mangles binary streams on 5.1:

  wsl -d Ubuntu -- cp ~/work/br-desktop/images/disk.img /mnt/g/VirtualDisk/master-penguin-linux.img
"@
}

$vdi = Join-Path $VMFolder "$VMName\$VMName.vdi"

if ($Replace) {
    & $VBoxManage unregistervm $VMName --delete 2>$null | Out-Null
    if (Test-Path (Join-Path $VMFolder $VMName)) {
        Remove-Item -Recurse -Force (Join-Path $VMFolder $VMName)
    }
}

Write-Host "creating VM $VMName"
& $VBoxManage createvm --name $VMName --ostype Linux_64 --register --basefolder $VMFolder | Out-Null

Write-Host "converting disk.img -> VDI (dynamic, so it shrinks to what is used)"
& $VBoxManage convertfromraw $ImgPath $vdi --format VDI | Out-Null

# Settings chosen to match the drivers compiled into this kernel:
#   - AHCI SATA        -> CONFIG_SATA_AHCI
#   - VMSVGA graphics  -> CONFIG_DRM_VMWGFX (vboxvideo is built in as a fallback)
#   - USB tablet       -> CONFIG_USB_HID, and absolute pointing so the mouse is
#                         not captured by the guest
& $VBoxManage modifyvm $VMName `
    --memory $MemoryMB --cpus $CPUs `
    --graphicscontroller vmsvga --vram 64 `
    --mouse usbtablet --audio-driver none `
    --nic1 nat --nictype1 82540EM `
    --firmware bios | Out-Null

& $VBoxManage storagectl $VMName --name "SATA" --add sata --controller IntelAhci --portcount 1 | Out-Null
& $VBoxManage storageattach $VMName --storagectl "SATA" --port 0 --device 0 --type hdd --medium $vdi | Out-Null

$size = [math]::Round((Get-Item $vdi).Length / 1MB, 1)
Write-Host ""
Write-Host "done. VDI is $size MB at:"
Write-Host "  $vdi"
Write-Host ""
Write-Host "Start it from the VirtualBox window, or:"
Write-Host "  & '$VBoxManage' startvm $VMName"

if ($Start) { & $VBoxManage startvm $VMName | Out-Null }
