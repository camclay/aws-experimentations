## AWS Purchase Reserved Hosts Script
## Designed to be used with the AWS Tools for Windows Powershell - https://aws.amazon.com/powershell/
## The script will attempt to purchase hosts in one region, for multiple availability zones
## Original design was based around 2 hosts, 1 in each availability zone


## Camille Clayton - 01032020

## Requires you to create a control file that has the value set at 0 or the program will stop 

## Setting Main Variables - Please provide the email and file path information below
$emailTo = ''
$emailer = ''
$smtpServer = ''
$smtpPort = ''

## Put in the locations you'd like the log to be stored, and the control file's path
$logFile = "C:\awsLog.txt"
$contPath = "C:\control.txt"

$startStamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss"

## Setting AWS Variables
## Valid AWS Regions can be found here: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html#using-regions-availability-zones-describe
$awsZoneOne = ""
$awsZoneTwo = ""
$awsRegion = ""

## Valid Instant Types - https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html#AvailableInstanceTypes
## Not all Instant Types are available in all regions
$insType = "" ## Ex: "m4.large" 

## AutoPlacement is required to be Off in AWS GovCloud, command will fail if this variable is ignored, can be set in AWS Commercial
$autoPlace = "off"

## Quantity of hosts for each Availability Zone
$quant = 1

## Creating empty variables to test for success
$resultOne = ""
$resultTwo = ""
$resultTest = ""

## Functions

## Error Function for the Control File
function controlError(){
    $Subject = "AWS Control File is Missing"
    $Body = "Attempted to purchase AWS hosts failed because the file is missing." + "`n" + "Error Message: " + $_
    Send-MailMessage -From $emailer -To $group -SmtpServer $smtpServer -Body $Body -Subject $Subject -Port $smtpPort
    endProgram
}

## Error Function for Availability Zones
function awsLogError($az, $errorOutput){
    #$error_output = "Attempted to purchase host on  $az and it did not succeed. Error Message is:  + $errorOutput"
    Write-Output "Attempted to purchase host on $az and it did not succeed. Error Message: $errorOutput " | Out-File -Append -FilePath $logFile
}

## Succesful Purchase Email Function
function awsPurchase($result,$az){
    $Subject = "Purchase of AWS Host Succeeded in $az"
    $Body = "Success, copying output of purchase: $result"
    Send-MailMessage -From $emailer -To $group -SmtpServer $smtpServer -Body $Body -Subject $Subject -Port $smtpPort
    Write-Output "Purchase of AWS Host Succeeded in $az Output: $result" | Out-File -Append -FilePath $logFile
}

## End Program cleanup function
function endProgram{
    Write-Output "Ending Script" | Out-File -Append -FilePath $logFile
    Get-Date -Format "MM/dd/yyyy HH:mm:ss" | Out-File -Append -FilePath $logFile
    exit
}

## Starting Main Code

Write-Output $startStamp | Out-File -FilePath $logFile -Append
Write-Output "Beginning to purchase hosts" | Out-File -FilePath $logFile -Append

## Control File Condition
## 0 == No Hosts Purchased, 1 == zone 1 purchased, 2 == zone 2 purchased, 3 == all purchased
Write-Output "Testing if the Control File Exists" | Out-File -FilePath $logFile -Append
try {
    $controlFile = Get-Content $contPath -ErrorAction Stop
} catch {
    controlError
}

## Control File was found, moving onto evaluating the Control File

Write-Output "Control File exists and the value is: $controlFile" | Out-File -Append -FilePath $logFile

if ($controlFile -eq 3){
    Write-Output "All necessary hosts have been purchased, please check the AWS Console for more info" | Out-File -Append -FilePath $logFile
    Write-Output "https://console.amazonaws-us-gov.com/ec2/home?region=us-gov-west-1#Hosts:sort=hostId" | Out-File -Append -FilePath $logFile
    endProgram
}

if($controlFile -eq 2){
    Write-Output "Currently a host has been purchased in Availability Zone 2" | Out-File -Append -FilePath $logFile
    Write-Output "Attempting to Purchase in Availability Zone 1" | Out-File -Append -FilePath $logFile
    try {
        $resultOne = New-EC2Host -AvailabilityZone $awsZoneOne -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsZoneOne $_
        endProgram
    }
    if ($resultOne -ne $resultTest){
        awsPurchase $resultOne $awsZoneOne
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    }
}

if($controlFile -eq 1){
    Write-Output "Currently a host has been purchased in Availability Zone 1 $awsZoneOne" | Out-File -Append -FilePath $logFile
    Write-Output "Attempting to Purchase in Availability Zone 2 $awsZoneTwo" | Out-File -Append -FilePath $logFile
    try {
        $resultTwo = New-EC2Host -AvailabilityZone $awsZoneTwo -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsZoneTwo $_
        endProgram
    }
    if ($resultTwo -ne $resultTest){
        awsPurchase $resultTwo $awsZoneTwo
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    }
}

if ($controlFile -eq 0){
    Write-Output "No hosts were previously purchased based on the Control File" | Out-File -Append -FilePath $logFile
    Write-Output "Attempting to Purchase in Availability Zone 1 $awsZoneOne" | Out-File -Append -FilePath $logFile
    
    try {
        $resultOne = New-EC2Host -AvailabilityZone $awsZoneOne -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    } catch {    
        awsLogError $awsZoneOne $_
    }
    
    Write-Output "Attempting to Purchase in Availability Zone 2 $awsZoneTwo" | Out-File -Append -FilePath $logFile
    try {
        $resultTwo = New-EC2Host -AvailabilityZone $awsZoneTwo -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsZoneTwo $_
    }
    
    if (($resultOne -ne $resultTest) -and ($resultTwo -ne $resultTest)){
        awsPurchase $resultOne $awsZoneOne
        awsPurchase $resultTwo $awsZoneTwo
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    } elseif (($resultOne -ne $resultTest) -and ($resultTwo -eq $resultTest)) {
        awsPurchase $resultOne $awsZoneOne
        Write-Output "1" | Out-File -FilePath $contPath
        endProgram
    } elseif (($resultOne -eq $resultTest) -and ($resultTwo -ne $resultTest)) {
        awsPurchase $resultTwo $awsZoneTwo
        Write-Output "2" | Out-File -FilePath $contPath
        endProgram
    } else {
        Write-Output "No hosts were able to be purchased" | Out-File -Append -FilePath $logFile
        endProgram
    }
}