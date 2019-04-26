function New-SlackPost {
    param ($issue)
    
    $payload = @{
        "channel" = "#psmonitor";
        "text" = "$issue";
        "icon_emoji" = ":bomb:";
        "username" = "PSMonitor";
    }

    Write-Verbose "Sending Slack Message"
    
    $slackWebRequest = @{
        Uri = "https://hooks.slack.com/services/$SlackToken"
        Method = "POST"
        Body = (ConvertTo-Json -Compress -InputObject $payload)
    }

    Invoke-WebRequest @slackWebRequest    

}