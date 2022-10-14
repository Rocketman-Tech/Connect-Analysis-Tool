# The CAT (Connect Analysis Tool)

## Background
In late 2021, I (Zac Hirschman) was a Jamf Certified Expert and an escalation point on the Jamf Connect Support Team. I was (1) ready to start working creatively in bash, (2) keenly aware of the need for something like a Jamf Connect Summary, and (3) ready to make puns in the names of my creations. All this led to a brainstorm and scripting session which now brings us the CAT, or Connect Analysis Tool.

The need for a client-side view into Jamf Connect is clear to anyone who has ever deployed it. Under CAT-less circumstances, it might be necessary to collect several pieces of information manually in order to troubleshoot any incidents. Now, we have a single script that can be executed either silently or through user interaction that puts a comprehensive report into the computer’s Jamf Pro inventory record.

## How it Works
This workflow is deployed through a policy, either in Self Service or another trigger. The effect on the Mac is a single log file created in /var/log with “CAT-the computer’s serial number-date of execution” as the file name. 

### Mechanism of operation:
- Policy initiates at its Trigger, or User initiates Policy through Self Service
- CAT creates log file
- CAT uploads log file to Attachments tab of Computer Inventory record

## Parameters
- Parameter 4: This string will be used in an API call to file upload the logs at the end
  - Label: API Basic Authentication
  - Type: String (must be a base64 hash)
  - Requirements: API User with the following permissions
    - Computers - Create
  - File Uploads - Create | Read | Update
  - Instructions: Generate a hash for parameter 4 with a command like:
    echo -n 'jamfapi:Jamf1234' | base64 | pbcopy
      - Example: YXBpdXNlcm5hbWU6cGFzc3dvcmQK
      
## Deployment Instructions
This workflow must be created and deployed through Jamf Pro using the following steps:
- Add ConnectAnalysisTool.sh to Jamf Pro with the parameter labels above
- Create an API User with the following permissions and generate its hash
  - Computers - Create
  - File Uploads - Create | Read | Update
- Create a Policy deploying ConnectAnalysisTool.sh through Self Service with the parameters set above

## Reading the log
The log is separated into a few groupings:

Begin CAT:


Basic Info at the top for version control and authchanger results


License Information:

Attempts to read and interpret the deployed License file


NOTE: For specific licensing issues, it may be necessary to contact Jamf directly. If the license file is encoded in a data block, the CAT will not be able to interpret it correctly and will throw a false negative “License in encoded data block or not found”

Full Property Lists:

Displays managed preferences for Jamf Connect Login & Menubar, and any associated State, Actions, Shares, and Authchanger preferences.


For more specific information about specific preferences, visit the admin’s guide at https://docs.jamf.com/jamf-connect/documentation/Preference_Key_Reference.html


LaunchAgent and Kerberos:


Displays the contents of the LaunchAgent, and any Kerberos tickets issued to the logged in user


Logs:


Displays the Jamf Connect Login logs from the most recent Login attempt, and the Menubar logs from the past 30 minutes prior to execution.

