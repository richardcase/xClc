$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Verbose -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xClcHelper.psm1 -Verbose:$false -ErrorAction Stop


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
        [Systen.String]
        $AccountAlias
    )
}