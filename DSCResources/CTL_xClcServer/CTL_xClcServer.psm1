$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Verbose -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xClcHelper.psm1 -Verbose:$false -ErrorAction Stop


<# 
    .SYNOPSIS
        Returns the current status of the CLC server

    .PARAMETER Name
        The name of the server

    .PARAMETER DataCenter
        The name of the data center

    .PARAMETER ClcCredential
        Credential to be used when connecting to CLC
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [Systen.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [Systen.String]
        $DataCenter,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $ClcCredential
    )

    $Name = $Name.ToUpper()

    Connect-Clc $ClcCredential


}