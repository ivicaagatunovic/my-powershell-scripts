function triage-dc(){
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
