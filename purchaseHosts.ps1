## AWS Purchase Reserved Hosts
## CCC- 09162019

## Setting Main Variables
## This example uses an open SMTP relay
## If you use an authenticated SMTP relay 
## This example has more info - https://www.undocumented-features.com/2018/05/22/send-authenticated-smtp-with-powershell/
$group = '' # To Email
$emailer = '' # From Email
$smtpServer = '' # Your local smtp relay
$logFile = "C:\awsLog.txt"
$contPath = "C:\control.txt"
## $contPathTest can be used to test the various control states
#$contPathTest = "C:\Users\cclayton\Documents\control2.txt"
$startStamp = Get-Date -Format "MM/dd/yyyy HH:mm:ss"

## Setting AWS Variables
$awsOne = "" # Region Availability Zone 1 eg: us-east-1a
$awsTwo = "" # Region Availability Zone 2 eg: us-east-1b

$awsRegion = # Set your aws region here
$insType = "m4.large"
## AutoPlacement is required to be Off in AWS GovCloud, command will fail if this variable is ignored. 
## AutoPlacement can be used in AWS Commercial Cloud to set future instances to automatically be created on this host
$autoPlace = "off"
## Quantity for each Availability Zone
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
    Send-MailMessage -From $emailer -To $group -SmtpServer $smtpServer -Body $Body -Subject $Subject
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
    Send-MailMessage -From $emailer -To $group -SmtpServer $smtpServer -Body $Body -Subject $Subject
    Write-Output "Purchase of AWS Host Succeeded in $az Output: $result" | Out-File -Append -FilePath $logFile
}

function endProgram{
    Write-Output "Ending Script" | Out-File -Append -FilePath $logFile
    Get-Date -Format "MM/dd/yyyy HH:mm:ss" | Out-File -Append -FilePath $logFile
    exit
}


## Starting Main Code

Write-Output $startStamp | Out-File -FilePath $logFile -Append
Write-Output "Beginning to purchase hosts" | Out-File -FilePath $logFile -Append

## Control File Condition
## 0 == No Hosts Purchased, 1 == us-west-1a purchased, 2 == us-west-1b purchased, 3 == all purchased
Write-Output "Testing if the Control File Exists" | Out-File -FilePath $logFile -Append
try {
    $controlFile = Get-Content $contPath -ErrorAction Stop
} catch {
    controlError
}

Write-Output "Control File exists and the value is: $controlFile" | Out-File -Append -FilePath $logFile

if ($controlFile -eq 3){
    Write-Output "All necessary hosts have been purchased, please check the AWS Console for more info" | Out-File -Append -FilePath $logFile
    endProgram
}

if($controlFile -eq 2){
    Write-Output "Currently a host has been purchased in AZ2" | Out-File -Append -FilePath $logFile
    Write-Output "Attempting to Purchase in Availability Zone 1" | Out-File -Append -FilePath $logFile
    try {
        $resultOne = New-EC2Host -AvailabilityZone $awsOne -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsOne $_
        endProgram
    }
    if ($resultOne -ne $resultTest){
        awsPurchase $resultOne $awsOne
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    }
}

if($controlFile -eq 1){
    Write-Output "Currently a host has been purchased in AZ1" | Out-File -Append -FilePath $logFile
    Write-Output "Attempting to Purchase in Availability Zone 2" | Out-File -Append -FilePath $logFile
    try {
        $resultTwo = New-EC2Host -AvailabilityZone $awsTwo -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsTwo $_
        endProgram
    }
    if ($resultTwo -ne $resultTest){
        awsPurchase $resultTwo $awsTwo
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    }
}

if ($controlFile -eq 0){
    Write-Output "Attempting to Purchase in Availability Zone 1" | Out-File -Append -FilePath $logFile
    
    try {
        $resultOne = New-EC2Host -AvailabilityZone $awsOne -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    } catch {    
        awsLogError $awsOne $_
    }
    
    Write-Output "Attempting to Purchase in Availability Zone 2" | Out-File -Append -FilePath $logFile
    try {
        $resultTwo = New-EC2Host -AvailabilityZone $awsTwo -InstanceType $insType -AutoPlacement $autoPlace -Quantity $quant -Region $awsRegion
    }
    catch {
        awsLogError $awsTwo $_
    }
    
    if (($resultOne -ne $resultTest) -and ($resultTwo -ne $resultTest)){
        awsPurchase $resultOne $awsOne
        awsPurchase $resultTwo $awsTwo
        Write-Output "3" | Out-File -FilePath $contPath
        endProgram
    } elseif (($resultOne -ne $resultTest) -and ($resultTwo -eq $resultTest)) {
        awsPurchase $resultOne $awsOne
        Write-Output "1" | Out-File -FilePath $contPath
        endProgram
    } elseif (($resultOne -eq $resultTest) -and ($resultTwo -ne $resultTest)) {
        awsPurchase $resultTwo $awsTwo
        Write-Output "2" | Out-File -FilePath $contPath
        endProgram
    } else {
        Write-Output "No hosts were able to be purchased" | Out-File -Append -FilePath $logFile
        endProgram
    }
}