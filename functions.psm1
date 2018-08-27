
function Connect-MSOnline {
    <#
.SYNOPSIS
    Pulls stored credentials to connect to MSOnline
#>
    if (!$(Get-PSSession | Where-Object { $_.ComputerName -eq "ps.outlook.com" })) {
        if (!(Test-Path ".\private\cred.txt")) { read-host -AsSecureString | ConvertFrom-SecureString | out-file ".\private\cred.txt" }

        $pswd = Get-Content ".\private\cred.txt" | ConvertTo-SecureString
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "$env:USERNAME@$Default_Domain", $pswd
        connect-msolservice -credential $cred

        $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell -Credential $cred -Authentication Basic -AllowRedirection
        Import-Module (Import-PSSession $Session -AllowClobber) -Global

    }
}

function Get-RemainingLicenses {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory)] [String] $SkuId
    )
    $details = Get-MsolAccountSku | Where-Object { $_.AccountSkuId -match $SkuId }
    $remaining = $details.ActiveUnits - $details.ConsumedUnits
    Write-Verbose "$($details.AccountSkuId): $remaining remaining"
    $remaining
}

Export-ModuleMember -Function *