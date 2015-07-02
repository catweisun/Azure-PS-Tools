Param(
[string]$subscriptionId="",
[int]$TimeWindow=25
)
$ErrorActionPreference ="Stop"

[void][System.Reflection.Assembly]::LoadWithPartialName("System.web")
$sbVMResult= New-Object System.Text.StringBuilder
#build output header
[void]$sbVMResult.AppendLine("ServiceName,VMName,Status")
if($subscriptionId -eq "")
{
    $subscriptionId = (Get-AzureSubscription -Current).SubscriptionId
}
Select-AzureSubscription -SubscriptionId $subscriptionId
#get management certificate thumbprint
$CertificateThumbprint = (Get-AzureAccount|Where{($_.Type -eq "Certificate") -and ($_.Subscriptions.Contains($subId))}).Id
#get started VM
$vmList = Get-AzureVM|where{$_.Status -eq "ReadyRole"}
foreach($vm in $vmList)
{
    #prepare query template
    $hostservice=$vm.ServiceName
    $deployment=$vm.DeploymentName
    $instanceName=$vm.Name
    $queryinstance = "/hostedservices/$hostservice/deployments/$deployment/roles/$instanceName"
    $queryns="namespace="
    $queryfields="Network In,Network Out,Disk Read Bytes/sec,Disk Write Bytes/sec,Percentage CPU"

    $query=[System.Web.HttpUtility]::UrlEncode($queryinstance)+"&namespace="+"&names="+ [System.Web.HttpUtility]::UrlEncode($queryfields).Replace("+"," ")
    $startTime= [System.DateTime]::UtcNow.AddMinutes(-1*$TimeWindow).ToString("o")
    $endTime=[System.DateTime]::UtcNow.ToString("o")
    $queryTime="&timeGrain=PT5M&startTime=$startTime&endTime=$endTime"

    $querytemplate = "https://management.core.chinacloudapi.cn/$subscriptionId/services/monitoring/metricvalues/query?resourceId=$query$queryTime"
    #request metric values
    $resp = Invoke-RestMethod -Method Get -Uri $querytemplate -CertificateThumbprint $CertificateThumbprint -ContentType "application-json" -Headers @{"x-ms-version"="2013-10-01"}
    #evaluate performance data
    $status = "Running"
    $result=$true
    if([System.String]::IsNullOrEmpty( $resp.MetricValueSetCollection.Value.MetricValueSet[0].MetricValues))
    {
        $status="Warning"  
    }
    else
    {
        foreach($valueset in $resp.MetricValueSetCollection.Value.MetricValueSet)
        {
            $metricResult=$true  
            switch($valueset.Name)
            {
                "Percentage CPU"
                {
                    $vAvgCPU = 0
                    foreach($metricCPU in $valueset.MetricValues.MetricValue)
                    {
                        if($vAvgCPU -lt $metricCPU.Average)
                        {
                            $vAvgCPU=$metricCPU.Average
                        }
                    }
                    if($vAvgCPU -lt 1.5)
                    {
                        $metricResult = $metricResult -and $true   
                    }
                    else
                    {
                        $metricResult=$false
                    }
                    break
                }
                Default 
                {
                    $vMax=0.0
                    $vMin=0.0
                    foreach($value in $valueset.MetricValues.MetricValue)
                    {
                        $vMax+= $value.Maximum
                        $vMin+=$value.Minimum
                    }
                    if(($vMax -eq $vmin) -and ($vMin -eq 0))
                    {
                        $metricResult = $metricResult -and $true                
                    }
                    else
                    {
                        $metricResult=$false
                    }
                    break        
                }
    }
        $result= $result -and $metricResult
        }
        if($result)
        {
            $status="Stuck"
        }
    }
    #output
    $strServiceName=$vm.ServiceName
    $strVMName=$vm.Name
    [void]$sbVMResult.AppendLine("$strServiceName,$strVMName,$status")
}
#print result
$sbVMResult.ToString()|ConvertFrom-Csv|Sort-Object Status|Format-Table -Property ServiceName,VMName -Wrap -GroupBy Status