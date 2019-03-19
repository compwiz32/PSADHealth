# PSADHealth

Table of Contents
- [PSADHealth](#psadhealth)
  - [Overview](#overview)
  - [History](#history)
  - [What does this toolkit do?](#what-does-this-toolkit-do)
  - [Who is this for?](#who-is-this-for)
  - [How to install module](#how-to-install-module)

## Overview

This project is a toolkit of AD specific health checks that you can run in your environment to ensure your Active Directory is running optimally. The goal is to have this tool run the various included tasks at regular intervals and alert you only when there is an issue.

## History

This toolkit was born from a chapter Mike Kanakos wrote for the PowerShell Conference Book volume 1 (2018). The toolkit is the logical progression from that chapter and is now open-source.

A huge "Thank You" goes out to **Stephen Valdinger** and **Greg Onstot** who have spent many hours helping this project get to a working state!

## What does this toolkit do?

The toolkit is a series of functions and scripts that are purpose built. Each tool in the kit is meant to check a particular aspect of Active Directory and return a result. These scripts are built by a group of individuals who recognized that the monitoring tools in their org's were either not able to perform these tests or the tools that could were too expensive to purchase. They created their own tools and collaborated to make a toolkit of unique, yet useful functions to help them keep better tabs on their AD infrastructure. 

These tools designed to be plugged into templates for email alerts, chatbot updates, slack notifications, etc. You can send the results to the tool that works best for you!

## Who is this for?

These toolkit is meant to be used by anyone who has a hand in maintaining an Active Directory instance. Maybe your org has no monitoring tools, maybe your looking to fill some gaps, or maybe you you have lost faith in the tools currently in use at your org. You can download this module and use it right away. 

## How to install module

 1. Download zip file to the computer that will run the module
 2. Unzip and rename folder that holds files from `PSHealth-Master` to `PSADHealth`
 3. Place renamed folder in the appropriate PowerShell folder on computer
    
    ```
    C:\Program Files (x86)\WindowsPowerShell\Modules 
    C:\Users\%username%\Documents\WindowsPowerShell\Modules
    ```

 4. Import Module
    `Import-Module PSADHealth`

 5. Verify Module is loaded
    `get-command -module PSADHealth`

 6. Run `Get-ADConfig` to see the default values included in module config JSON.

 7. Run `Set-PSADHealthConfig` to change/specify the values you want to use

 8. Verify the values you set are loaded.
   `Get-ADConfig -ConfigurationFile c:\users\%username%\adconfig.json`

9. Configure scheduled Tasks or Scheduled Jobs to run the tests at intervals you choose. 
