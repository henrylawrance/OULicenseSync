$global:VerbosePreference = "Continue"

$global:Default_Domain = "domain.edu"

Import-Module .\functions.psm1
Connect-MSOnline

$licensetype = get-content .\config_licensetype.json | ConvertFrom-Json


$Managed_OUs = @('Students', 'Alumni', 'Faculty-Staff', 'Other')

$ADAccounts = @()
$Managed_OUs | ForEach-Object {
    $SearchBase = "ou=" + $_ + ",dc=" + $($Default_Domain.split(".")[0]) + ",dc=" + $($Default_Domain.split(".")[1])
    $ADAccounts += get-aduser -filter {Enabled -eq $True} -SearchBase $SearchBase -Properties DistinguishedName,UserPrincipalName
}


ForEach ($user in $ADAccounts) {
    Write-Verbose $user.UserPrincipalName
    #Verify Usage Location
    if ((Get-MsolUser -UserPrincipalName $user.UserPrincipalName | Select-Object UsageLocation) -ne 'US') {
        Set-MsolUser -UserPrincipalName $user.UserPrincipalName -UsageLocation US
    }
    #Get Currently Set Licenses
    $setlicense = (Get-MsolUser -UserPrincipalName $user.UserPrincipalName ).Licenses.AccountSkuId

    #Identify Licenses to be Removed
    $remLicense = $($licensetype | Where-Object { $_.type -eq $user.DistinguishedName.Split(",")[1].replace("OU=", "")}).absent | Where-Object { $setlicense -contains $_}
    #Remove them
    if ($remLicense.count -gt 0) {
        $remLicense | ForEach-Object {     
            Write-Verbose "Remove: $_ User: $($user.UserPrincipalName)"
            Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -RemoveLicenses $_
            "Set-MsolUserLicense -UserPrincipalName $($user.UserPrincipalName) -AddLicenses $_" | out-file -enc ascii undo_removes.txt -Append 
        }
    }
    
    #Identify Licenses to be Added
    $addLicense = $($licensetype | Where-Object { $_.type -eq $user.DistinguishedName.Split(",")[1].replace("OU=", "")}).present | Where-Object { $setlicense -notcontains $_}
    #Add them
    if ($addLicense.count -gt 0) {
        $addLicense | ForEach-Object { 
            if ((Get-RemainingLicenses -SkuId $_) -gt 0) {
                Write-Verbose "Add: $_ User: $($user.UserPrincipalName)"
                Set-MsolUserLicense -UserPrincipalName $user.UserPrincipalName -AddLicenses $_
                "Set-MsolUserLicense -UserPrincipalName $($user.UserPrincipalName) -RemoveLicenses $_" | out-file -enc ascii undo_additions.txt -Append
            }
            else {
                Write-Warning "!!! Out of license $_ !!!"
            }
        }
    }
}
