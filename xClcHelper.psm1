# Set Global Module Verbose
$VerbosePreference = 'Continue'

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
        $client = New-Object System.Net.Http.HttpClient
        $header = New-Object System.Net.Http.Headers.MediaTypeWithQualityHeaderValue "application/json"
        $client.DefaultRequestHeaders.Accept.Add($header)
        $user = $ClcCredential.GetNetworkCredential().UserName
        $pwd = $ClcCredential.GetNetworkCredential().Password
        $body = "{ `"username`":`"$user`", `"password`":`"$pwd`" }"
        $content = New-Object System.Net.Http.StringContent $body, $null, "application/json" 
        $result = $client.PostAsync("https://api.ctl.io/v2/authentication/login", $content).Result
        $response = $result.Content.ReadAsStringAsync().Result

        Write-Host $response

    }
    else {
        Throw "You must specify the CLC credentials"
    }
}