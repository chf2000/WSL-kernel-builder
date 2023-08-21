$kernel_org = Invoke-WebRequest "https://www.kernel.org/"
$kernel_org = $kernel_org.Content.Replace("&nbsp;", "")
$xmldata = [xml]($kernel_org)
$latest_stable_kernel_uri = $xmldata.SelectNodes('/html/body/aside/article/table[2]/tr[2]/td[1]/a/@href')[0].Value
$kernel_source_filename = $latest_stable_kernel_uri.Split('/')[-1]
$kernel_version = $kernel_source_filename.TrimStart("linux-").TrimEnd(".tar.xz")
Write-Host "Latest Stable Linux kernel version is $kernel_version ."
if (Test-Path $kernel_source_filename) {
    Write-Host "Source File already exists. Skip downloading."
} else {
    Write-Host "Downloading ..."
    Invoke-WebRequest $latest_stable_kernel_uri -OutFile ./$kernel_source_filename
}

Write-Host "Downloading latest kernel config from M$ ..."
$ProgressPreference = 'SilentlyContinue'
$wsl_kernel_config_uri = "https://raw.githubusercontent.com/microsoft/WSL2-Linux-Kernel/linux-msft-wsl-5.15.y/Microsoft/config-wsl"
$wsl_kernel_config_filename = "config-wsl"
Invoke-WebRequest $wsl_kernel_config_uri -OutFile ./$wsl_kernel_config_filename
$ProgressPreference = 'Continue'

Write-Host "Extracting source files ..."
$DISTRO = "ubuntu"

function Start-LinuxShellCommand {
    param (
        $shellscript
    )
    wsl -d $DISTRO bash -c $shellscript
    
}

Start-LinuxShellCommand "cd /tmp/ && rm -rf linux*"
Start-LinuxShellCommand "cp $kernel_source_filename /tmp/$kernel_source_filename"
Start-LinuxShellCommand "cd /tmp/ && tar xf $kernel_source_filename"
Start-LinuxShellCommand "cp $wsl_kernel_config_filename /tmp/linux-$kernel_version/.config"

Write-Host "Installing build dependencies ..."
Start-LinuxShellCommand "sudo apt update && sudo apt upgrade && sudo apt install build-essential flex bison dwarves libssl-dev libelf-dev libncurses-dev bc -y"

Clear-Host
Write-Host "Configure your own kernel!"
Start-LinuxShellCommand "cd /tmp/linux-$kernel_version && make menuconfig -j $Env:NUMBER_OF_PROCESSORS"

Clear-Host
Write-Host -NoNewline "Compiling the kernel in 5"
for ($i = 4; $i -ge 0; $i--) {
    Start-Sleep -Seconds 1
    Write-Host -NoNewline "...$i"
}
Write-Host
Write-Host "请坐和放宽。"
Start-LinuxShellCommand "cd /tmp/linux-$kernel_version && make -j $Env:NUMBER_OF_PROCESSORS"
Start-LinuxShellCommand "cd /tmp/linux-$kernel_version && make -j $Env:NUMBER_OF_PROCESSORS headers_install INSTALL_HDR_PATH=/tmp/linux-$kernel_version-headers/"
Start-LinuxShellCommand "cp -r /tmp/linux-$kernel_version-headers/ ./"

Write-Host "Configuring new kernel ..."
Start-LinuxShellCommand "cp /tmp/linux-$kernel_version/vmlinux ./vmlinux-$kernel_version"
$wslconfig = Get-Content .\.wslconfig.template
$kernel_path = $(Get-Location).ToString() + "\vmlinux-$kernel_version"
$wslconfig = $wslconfig.Replace("{KERNELPATH}", $kernel_path.Replace("\","\\"))
Move-Item ~/.wslconfig ~/.wslconfig.old
Out-File -FilePath ~/.wslconfig -InputObject $wslconfig

Write-Host "Restarting WSL environment ..."
wsl --shutdown
Start-Sleep -Seconds 6
Clear-Host
Write-Host "Enjoy!"
Start-LinuxShellCommand "uname -a"
wsl -d $DISTRO