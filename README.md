# xClc
PowerShell DSC resource for CLC

# Sample usage
$secpasswd = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
$clccreds = New-Object System.Management.Automation.PSCredential("myclcusername", $secpasswd
Connect-CLC $clccreds
