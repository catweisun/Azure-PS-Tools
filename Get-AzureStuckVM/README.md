## Get-AzureStuckVM
List VM with grouping status including running\warning(no performance data)\stuck(no response)

The script just need two optional parameters as below:
Parameter Name|Default Value|Description
subscriptionId|The current subscription Id in your powershell context|It’s used to identify the subscription you want to use
TimeWindow|30|The value is used to assign the timewindow for performance data collection, the performance data minimum latency is 15min in common.But if the data latency is high than the timewindow, the script will assign the warning status in output, you should check it manually.
