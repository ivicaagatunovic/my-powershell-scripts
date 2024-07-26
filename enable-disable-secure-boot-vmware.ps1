<#
.SYNOPSIS
    This script manages VM secure boot settings in a VMware environment. 
    It includes functions to sort servers by data center, check and update secure boot settings, and manage VM power states as necessary.

.DESCRIPTION
    The script contains functions to:
    1. Categorize servers into different data centers based on naming conventions.
    2. Retrieve and update the secure boot setting of virtual machines (VMs).
    3. Disable or enable secure boot on VMs, handling VM power state transitions as needed.
    4. Connect to specified vCenter servers to apply configuration changes.

.EXAMPLE
    $cred = Get-Credential
    $unsortedArray = 'ivica01.domain.local', 'ivica02.domain.local'
    $sortedServerHash = triage-dc -serverArray $unsortedArray
    enable-vmsecureboot -serverArray $sortedServerHash.dc2 -vcenter 'vcenter02.domain.local' -cred $cred

    This example sorts the provided server array by data center and enables secure boot on VMs located in data center 'dc2' using the specified vCenter server.

.NOTES
    Ensure that VMware PowerCLI is installed and properly configured.
    Update the `$unsortedArray` and vCenter server addresses according to your environment's requirements.
        Author : Ivica Agatunovic
        WebSite: https://github.com/ivicaagatunovic
        Linkedin: www.linkedin.com/in/ivica-agatunovic-96090024
#>

function triage-dc(){
    <#
    .SYNOPSIS
        Sorts an array of server names into different data centers based on naming patterns.

    .DESCRIPTION
        This function takes an array of server names and sorts them into a hashtable where the keys are data center names and the values are arrays of server names belonging to each data center. The sorting is done based on regex patterns matching the server names.

    .PARAMETER serverArray
        An array of server names to be sorted.

    .OUTPUTS
        A hashtable where keys are data center names (e.g., 'dc1', 'dc2', 'dc3') and values are arrays of server names that match the respective data center pattern.
    #>
    param(
        [String[]]$serverArray
    )
    $sorted_per_dc=@{
        dc1 = @();
        dc2 = @();
        dc3 = @();
    }
    foreach($i in $serverArray ){
        switch -regex ($i){
            "^(.+)([0-9]+)(e1)(\.[a-zA-Z]+)+$"{$sorted_per_dc.dc1 += $i}
            "^(.+)([0-9]+)(e2)(\.[a-zA-Z]+)+$"{$sorted_per_dc.dc2 += $i}
            "^(.+)([0-9]+)(e3)(\.[a-zA-Z]+)+$"{$sorted_per_dc.dc3 += $i}
        }
    }
    return $sorted_per_dc
}

Function get-vmsecureboot {
    <#
    .SYNOPSIS
        Retrieves the secure boot status of a virtual machine.

    .DESCRIPTION
        This function checks whether secure boot is enabled or disabled on a VM by inspecting its boot options.

    .PARAMETER vm
        The virtual machine object for which the secure boot status is to be retrieved.

    .OUTPUTS
        Returns a string indicating the secure boot status: 'enabled' or 'disabled'.
    #>
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)
        ]
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$vm
    )

    $secureBootSetting = if ($vm.ExtensionData.Config.BootOptions.EfiSecureBootEnabled) { "enabled" } else { "disabled" }
    return $secureBootSetting

}

function disable-vmsecureboot() {
    <#
    .SYNOPSIS
        Disables secure boot on specified VMs by connecting to a vCenter server.

    .DESCRIPTION
        This function connects to the specified vCenter server, retrieves VMs from the provided server array, and disables secure boot on them. It handles VM power state transitions, ensuring VMs are powered off before making configuration changes, and then restarts them if necessary.

    .PARAMETER serverArray
        An array of server names whose secure boot settings are to be disabled.

    .PARAMETER vcenter
        The vCenter server to connect to for applying the secure boot settings.

    .PARAMETER cred
        The credentials used to authenticate with the vCenter server.

    .OUTPUTS
        Writes status messages indicating the progress and outcome of the secure boot configuration changes.
    #>
    param(
        [Parameter(Mandatory)]
        [String[]]$serverArray,
        [Parameter(Mandatory)]
        [Validateset('vcenter01.domain.local', 'vcenter02.domain.local', 'vcenter03.domain.local')]
        $vcenter,
        [Parameter(Mandatory)]
        [pscredential]$cred
    )
    Connect-VIServer -Server $vcenter -Credential $cred
    foreach ($serv in $serverArray) {
        $vm = get-vm -Name $serv
        $secureBootStatus = get-vmsecureboot -vm $vm
        if ($secureBootStatus -eq 'enabled') {
            if ($vm.powerstate -ne 'PoweredOff') {
                write-output "INFO :: VM $serv is poweredOn, stopping the vm."
                (stop-vm -vm $vm -Confirm:$false).powerstate
            }
            if ((get-vm -Name $serv).powerstate -eq 'PoweredOff') {
                write-output "INFO :: VM $serv is poweredoff, disabling secureboot now"
                $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
                $boot = New-Object VMware.Vim.VirtualMachineBootOptions
                $boot.EfiSecureBootEnabled = $false
                $spec.BootOptions = $boot
                $vm.ExtensionData.ReconfigVM($spec)
            }
            if((get-vmsecureboot -vm $(get-vm -Name $serv)) -eq 'disabled'){
                write-output "INFO :: $serv is reconfigured to have secureboot disabled, starting the now"
                (start-vm $vm).powerstate
            } else {
                write-output "ERROR :: $serv does not have secureboot disabled after actions taken, remains powered off, ACTION REQUIRED."
            }
        } else {
            write-output "INFO :: $serv is already reconfigured to have secureboot disabled nothing to do."
        }
        start-sleep 10
    }
    Disconnect-VIServer -Server $vcenter -Confirm:$false
}

function enable-vmsecureboot() {
    <#
    .SYNOPSIS
        Enables secure boot on specified VMs by connecting to a vCenter server.

    .DESCRIPTION
        This function connects to the specified vCenter server, retrieves VMs from the provided server array, and enables secure boot on them. It handles VM power state transitions, ensuring VMs are powered off before making configuration changes, and then restarts them if necessary.

    .PARAMETER serverArray
        An array of server names whose secure boot settings are to be enabled.

    .PARAMETER vcenter
        The vCenter server to connect to for applying the secure boot settings.

    .PARAMETER cred
        The credentials used to authenticate with the vCenter server.

    .OUTPUTS
        Writes status messages indicating the progress and outcome of the secure boot configuration changes.
    #>
    param(
        [Parameter(Mandatory)]
        [String[]]$serverArray,
        [Parameter(Mandatory)]
        [Validateset('vcenter01.domain.local', 'vcenter02.domain.local', 'vcenter03.domain.local')]
        $vcenter,
        [Parameter(Mandatory)]
        [pscredential]$cred
    )
    Connect-VIServer -Server $vcenter -Credential $cred
    foreach ($serv in $serverArray) {
        $vm = get-vm -Name $serv
        $secureBootStatus = get-vmsecureboot -vm $vm
        if ($secureBootStatus -eq 'disabled') {
            if ($vm.powerstate -ne 'PoweredOff') {
                write-output "INFO :: VM $serv is poweredOn, stopping the vm."
                (stop-vm -vm $vm -Confirm:$false).powerstate
            }
            if ((get-vm -Name $serv).powerstate -eq 'PoweredOff') {
                write-output "INFO :: VM $serv is poweredoff, enabling secureboot now"
                $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
                $spec.Firmware = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
                $boot = New-Object VMware.Vim.VirtualMachineBootOptions
                $boot.EfiSecureBootEnabled = $true
                $spec.BootOptions = $boot
                $vm.ExtensionData.ReconfigVM($spec)
            }
            if((get-vmsecureboot -vm $(get-vm -Name $serv)) -eq 'enabled'){
                write-output "INFO :: $serv is reconfigured to have secureboot enabled, starting the now"
                (start-vm $vm).powerstate
            } else {
                write-output "ERROR :: $serv does not have secureboot enabled after actions taken, remains powered off, ACTION REQUIRED."
            }
        } else {
            write-output "INFO :: $serv is already reconfigured to have secureboot enabled nothing to do."
        }
        start-sleep 10
    }
    Disconnect-VIServer -Server $vcenter -Confirm:$false
}

#fill in the variables

$cred = get-credential
$unsortedarray= 'ivica01.domain.local','ivica02.domain.local'
#sort your server array to a hashtable with datacenters as key and array of servers in that dc as value
$sorted_server_hash = triage-dc -serverArray $unsortedarray 

# run the disable secure boot on each dc at a time (change the serverarray and the vcenter address accordingly)
#disable-vmsecureboot -serverArray $sorted_server_hash.ams1 -vcenter vcenter03.infra.eu.ginfra.net -cred $cred
enable-vmsecureboot -serverArray $sorted_server_hash.dc2 -vcenter vcenter02.domain.local -cred $cred
