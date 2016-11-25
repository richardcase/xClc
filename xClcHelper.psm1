# Set Global Module Verbose
$VerbosePreference = 'Continue'

# Load Localization Data 
Import-LocalizedData LocalizedData -filename xClc.strings.psd1 -ErrorAction SilentlyContinue 
Import-LocalizedData USLocalizedData -filename xClc.strings.psd1 -UICulture en-US -ErrorAction SilentlyContinue

# Create the config directory 
$configDir = "$env:USERPROFILE\Documents\xClc\0.1"
$configPath = "$configDir\Config.ps1xml"

if (!(Test-Path -PathType Container -Path $configDir))
{
    New-Item -ItemType Directory -Path $configDir
}

<#
    .SYNOPSIS
        Connects to CLC and saves credentials for caching.
    .PARAMETER ClcCredential
        Credentials to use when connecting to CLC.  
#>
function Connect-CLC
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $ClcCredential
    )

    if ($ClcCredential)
    {
        if (Test-Path $configPath) {
            New-VerboseMessage "Cached CLC credential found, importing. $configPath"
            try {
                $accountDetails = Import-Clixml -Path $configPath -ErrorAction STOP
                #TODO: add username/pwd validation and timeout
            }
            catch {
                New-WarningMessage "Corrupt CLC credential file, logging in again"
            }
        }
        
        if ($accountDetails -eq $null)
        {
            $user = $ClcCredential.GetNetworkCredential().UserName
            $pwd = $ClcCredential.GetNetworkCredential().Password
            $body = "{ `"username`":`"$user`", `"password`":`"$pwd`" }"

            $response = Invoke-WebRequest -Uri "https://api.ctl.io/v2/authentication/login" -Method Post -Body $body -ContentType "application/json" -UserAgent "xClc Powershell"


            if ($response.StatusCode -eq 200)
            {
                $results = $response.Content | ConvertFrom-Json | select bearerToken, accountAlias
                
                $date = Get-Date
                $props = @{
                    Alias = $results.accountAlias
                    Token = ConvertTo-SecureString $results.bearerToken -AsPlainText -Force
                    #Date = ConvertTo-SecureString $date.ToUniversalTime() -AsPlainText -Force Get-Date
                    Computer = ConvertTo-SecureString $env:COMPUTERNAME -AsPlainText -Force
                }
                $accountDetails = New-Object psobject -Property $props

                $accountDetails | Export-Clixml $configPath -Force
            
            } else {
                Throw "Error connecting to CLC"
            }
        }
    }
    else {
        Throw "You must specify the CLC credentials"
    }

    $accountAlias = $accountDetails.Alias
    New-VerboseMessage -Message "Connected to CLC with account alias $accountAlias"

    return $accountDetails
}

function Invoke-ClcRequest
{
    [CmdletBinding()]
    param
    (
        [ValidateNotNull()]
        [System.String]
        $Url,

        [ValidateNotNull()]
        [System.String]
        $Body,

        [ValidateNotNull()]
        [ValidateSet('Get', 'Post', 'Put','Delete')]
        [System.String]
        $Method,

        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        $ClcCredential
    )
    $accountDetails = Connect-CLC $ClcCredential

    $credential = New-Object System.Management.Automation.PSCredential("user", $accountDetails.Token)
    $beareHeader = "Bearer " + $credential.GetNetworkCredential().Password

    if (($Method -eq "Get") -or ($Method -eq "Delete") )
    {
        $response = Invoke-WebRequest -Uri $Url -Method $Method -ContentType "application/json" -UserAgent "xClc Powershell" -Headers @{Authorization = $beareHeader}
    } else {
        $response = Invoke-WebRequest -Uri $Url -Method $Method -Body $body -ContentType "application/json" -UserAgent "xClc Powershell" -Headers @{Authorization = $beareHeader}
    }
    
    $returnCode = $response.StatusCode
    switch ($returnCode)
    {
        200 { return $response.Content | ConvertFrom-Json }
        201 { return $response.Content | ConvertFrom-Json }
        202 { return $response.Content | ConvertFrom-Json }
        204 { return  }
        400 { throw New-TerminatingError -ErrorType ResponseBadRequest -ErrorCategory SyntaxError  }
        401 { throw New-TerminatingError -ErrorType ResponseUnauthorised -ErrorCategory AuthenticationError }
        403 { throw New-TerminatingError -ErrorType ResponseForbidden  -ErrorCategory SecurityError }
        404 { throw New-TerminatingError -ErrorType ResponseNotFound -FormatArgs @($Url) -ErrorCategory ObjectNotFound }
        500 { throw New-TerminatingError -ErrorType ResponseServerError  -ErrorCategory DeviceError }
    }
}

function Get-ClcCredentials
{
    if (Test-Path $configPath) {
        New-VerboseMessage "Cached CLC credential found, importing. $configPath"
        try {
            $accountDetails = Import-Clixml -Path $configPath -ErrorAction STOP
            #TODO: add username/pwd validation and timeout
        }
        catch {
            New-WarningMessage "Corrupt CLC credential file. Please delete"
        }
    }

    return $accountDetails
}

<#
    .SYNOPSIS
        Returns a localized error message.
    .PARAMETER ErrorType
        String containing the key of the localized error message.
    .PARAMETER FormatArgs
        Collection of strings to replace format objects in the error message.
    .PARAMETER ErrorCategory
        The category to use for the error message. Default value is 'OperationStopped'.
        Valid values are a value from the enumeration System.Management.Automation.ErrorCategory. 
    .PARAMETER TargetObject
        The object that was being operated on when the error occurred. 
    .PARAMETER InnerException
        Exception object that was thorwn when the error occured, which will be added to the final error message.  
#>
function New-TerminatingError 
{
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ErrorType,

        [Parameter(Mandatory = $false)]
        [String[]]
        $FormatArgs,

        [Parameter(Mandatory = $false)]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped,
        
        [Parameter(Mandatory = $false)]
        [Object]
        $TargetObject = $null,

        [Parameter(Mandatory = $false)]
        [System.Exception]
        $InnerException = $null
    )
    
    $errorMessage = $LocalizedData.$ErrorType
    
    if(!$errorMessage)
    {
        $errorMessage = ($LocalizedData.NoKeyFound -f $ErrorType)

        if(!$errorMessage)
        {
            $errorMessage = ("No Localization key found for key: {0}" -f $ErrorType)
        }
    }

    $errorMessage = ($errorMessage -f $FormatArgs)
    
    if( $InnerException )
    {
        $errorMessage += " InnerException: $($InnerException.Message)"
    }
    
    $callStack = Get-PSCallStack 

    # Get Name of calling script
    if($callStack[1] -and $callStack[1].ScriptName)
    {
        $scriptPath = $callStack[1].ScriptName

        $callingScriptName = $scriptPath.Split('\')[-1].Split('.')[0]
    
        $errorId = "$callingScriptName.$ErrorType"
    }
    else
    {
        $errorId = $ErrorType
    }

    Write-Verbose -Message "$($USLocalizedData.$ErrorType -f $FormatArgs) | ErrorType: $errorId"

    $exception = New-Object System.Exception $errorMessage, $InnerException    
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $errorId, $ErrorCategory, $TargetObject

    return $errorRecord
}

<#
    .SYNOPSIS
        Displays a localized warning message.
    .PARAMETER WarningType
        String containing the key of the localized warning message.
    
    .PARAMETER FormatArgs
        Collection of strings to replace format objects in warning message.
#>
function New-WarningMessage
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]
        $WarningType,

        [String[]]
        $FormatArgs
    )

    ## Attempt to get the string from the localized data
    $warningMessage = $LocalizedData.$WarningType

    ## Ensure there is a message present in the localization file
    if (!$warningMessage)
    {
        $errorParams = @{
            ErrorType = 'NoKeyFound'
            FormatArgs = $WarningType
            ErrorCategory = 'InvalidArgument'
            TargetObject = 'New-WarningMessage'
        }

        ## Raise an error indicating the localization data is not present
        throw New-TerminatingError @errorParams 
    }

    ## Apply formatting
    $warningMessage = $warningMessage -f $FormatArgs

    ## Write the message as a warning
    Write-Warning -Message $warningMessage
}

<#
    .SYNOPSIS
    Displays a standardized verbose message.
    .PARAMETER Message
    String containing the key of the localized warning message.
#>
function New-VerboseMessage
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([String])]
    Param
    (
        [Parameter(Mandatory=$true)]
        $Message
    )
    Write-Verbose -Message ((Get-Date -format yyyy-MM-dd_HH-mm-ss) + ": $Message");
}