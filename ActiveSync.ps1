﻿<#
    .SYNOPSIS
    Performs autodiscover for the given user and protocol

    .DESCRIPTION
    Performs autodiscover for the given user using AutoDiscover V2. Returns the url of the requested protocol

    .Example
    Get-AADIntEASAutoDiscover -Email user@company.com

    Protocol   Url                                                      
    --------   ---                                                      
    ActiveSync https://outlook.office365.com/Microsoft-Server-ActiveSync


    .Example
    Get-AADIntEASAutoDiscover -Email user@company.com -Protocol Ews

    Protocol Url                                            
    -------- ---                                            
    ews      https://outlook.office365.com/EWS/Exchange.asmx
    
#>
function Get-EASAutoDiscover
{
    Param(
            
            [Parameter(Mandatory=$True)]
            [String]$Email,
            [ValidateSet('Rest','ActiveSync','Ews','Substrate','Substratesearchservice','AutodiscoverV1','substratesearchservice','substratenotificationservice','outlookmeetingscheduler','outlookpay')]
            [String]$Protocol="ActiveSync"
        )
    Process
    {
        
        $url = "https://outlook.office365.com/Autodiscover/Autodiscover.json?Email=$Email&Protocol=$Protocol"

        $response=Invoke-RestMethod -Uri $url -Method Get
        $response
    }
}

<#
    .SYNOPSIS
    Performs autodiscover for the given user

    .DESCRIPTION
    Performs autodiscover for the given user. Returns the url of ActiveSync service

    .Example
    Get-AADIntEASAutoDiscoverV1 -Credentials $Cred

    https://outlook.office365.com/Microsoft-Server-ActiveSync
    
#>
function Get-EASAutoDiscoverV1
{
    Param(
            
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken
        )
    Process
    {
        $auth = Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken
        $headers = @{
            "Authorization" = $auth
            "Content-Type" = "text/xml"
        }

        $user=Get-UserName -Auth $auth
        $domain=$user.Split("@")[1]

        # Default host for Office 365
        $hostname = "autodiscover-s.outlook.com"
        
        $url = "https://$hostname/Autodiscover/Autodiscover.xml"

        $body=@"
            <Autodiscover xmlns="http://schemas.microsoft.com/exchange/autodiscover/mobilesync/requestschema/2006">
            <Request>
                <EMailAddress>$user</EMailAddress>
                <AcceptableResponseSchema>http://schemas.microsoft.com/exchange/autodiscover/mobilesync/responseschema/2006</AcceptableResponseSchema>
            </Request>
            </Autodiscover>
"@
        
        $response=Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -TimeoutSec 60
        $response.Autodiscover.Response.Action.Settings.Server.Url
    }
}

<#
    .SYNOPSIS
    Gets user's ActiveSync options

    .DESCRIPTION
    Gets user's ActiveSync options. Shows for instance Front and Backend server names. 
    The first two characters indicates the city: HE=Helsinki, VI=Vienna, DB=Dublin, AM=Amsterdam, etc.

    .Example
    Get-AADIntEASOptions -Credentials $Cred

    Key                   Value                                                                                                              
    ---                   -----                                                                                                              
    Allow                 OPTIONS,POST                                                                                                       
    request-id            61e62c8d-f689-4d08-b0d7-4ffa1e42e1ea                                                                               
    X-CalculatedBETarget  HE1PR0802MB2202.eurprd08.prod.outlook.com                                                                          
    X-BackEndHttpStatus   200                                                                                                                
    X-RUM-Validated       1                                                                                                                  
    MS-Server-ActiveSync  15.20                                                                                                              
    MS-ASProtocolVersions 2.0,2.1,2.5,12.0,12.1,14.0,14.1,16.0,16.1                                                                          
    MS-ASProtocolCommands Sync,SendMail,SmartForward,SmartReply,GetAttachment,GetHierarchy,CreateCollection,DeleteCollection,MoveCollectio...
    Public                OPTIONS,POST                                                                                                       
    X-MS-BackOffDuration  L/-469                                                                                                             
    X-DiagInfo            HE1PR0802MB2202                                                                                                    
    X-BEServer            HE1PR0802MB2202                                                                                                    
    X-FEServer            HE1PR1001CA0019                                                                                                    
    Content-Length        0                                                                                                                  
    Cache-Control         private                                                                                                            
    Content-Type          application/vnd.ms-sync.wbxml                                                                                      
    Date                  Wed, 03 Apr 2019 17:40:18 GMT                                                                                      
    Server                Microsoft-IIS/10.0                                                                                                 
    X-AspNet-Version      4.0.30319                                                                                                          
    X-Powered-By          ASP.NET 
#>
function Get-EASOptions
{
    Param(
            
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken
        )
    Process
    {

        $headers = @{
            "Authorization" = Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken
        }
        
        $response=Invoke-WebRequest -Uri "https://outlook.office365.com/Microsoft-Server-ActiveSync" -Method Options -Headers $headers -TimeoutSec 5
        $response.headers
    }
}


# Get folders to sync
function Get-EASFolderSync
{
    Param(
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken,
            [Parameter(Mandatory=$True)]
            [String]$DeviceId,
            [Parameter(Mandatory=$False)]
            [String]$DeviceType="Android"
        )
    Process
    {
        [xml]$request=@"
        <FolderSync xmlns="FolderHierarchy">
            <SyncKey>0</SyncKey>
        </FolderSync>
"@

        $response = Call-EAS -Request $request -Command FolderSync -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType

        return $response
    }
}

<#
    .SYNOPSIS
    Sends mail message using ActiveSync

    .DESCRIPTION
    Sends mail using ActiveSync using the account of given credentials. 
    Supports both Basic and Modern Authentication.
    Message MUST be html (or plaintext) and SHOULD be Base64 encoded (if not, it's automatically converted).

    .Example
    PS C:\>$Cred=Get-Credential
    PS C:\>Send-AADIntEASMessage -Credentials $Cred -DeviceId androidc481040056 -DeviceType Android -Recipient someone@company.com -Subject "An email" -Message "This is a message!"

    .Example
    PS C:\>$At=Get-AADIntAccessTokenForEXO
    PS C:\>Send-AADIntEASMessage -AccessToken $At -DeviceId androidc481040056 -DeviceType Android -Recipient someone@company.com -Subject "An email" -Message "This is a message!"
   
#>
function Send-EASMessage
{
    Param(
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken,
            [Parameter(Mandatory=$True)]
            [String]$Recipient,
            [Parameter(Mandatory=$True)]
            [String]$Subject,
            [Parameter(Mandatory=$True)]
            [String]$Message,
            [Parameter(Mandatory=$True)]
            [String]$DeviceId,
            [Parameter(Mandatory=$False)]
            [String]$DeviceType="Android"
        )
    Process
    {
        $messageId = (New-Guid).ToString()
        [xml]$request=@"
<SendMail xmlns="ComposeMail"><ClientId>$messageId</ClientId><SaveInSentItems></SaveInSentItems><MIME><![CDATA[Date: Wed, 03 Apr 2019 08:51:41 +0300
Subject: $Subject
Message-ID: <$messageId>
From: rudolf@santaclaus.org
To: $recipient
Importance: Normal
X-Priority: 3
X-MSMail-Priority: Normal
MIME-Version: 1.0
Content-Type: text/html; charset=utf-8
Content-Transfer-Encoding: base64

$(Get-MessageAsBase64 -Message $Message)
]]></MIME></SendMail>
"@

        $response = Call-EAS -Request $request -Command SendMail -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType

        return $response
    }
}

<#
    .SYNOPSIS
    Sets users device settings using ActiveSync

    .DESCRIPTION
    Sets users device settings using ActiveSync. You can change device's Model, IMEI, FriendlyName, OS, OSLanguage, PhoneNumber, MobileOperator, and User-Agent.
    All empty properties are cleared from the device settings. I.e., if IMEI is not given, it will be cleared.

    .Example
    PS C:\>$Cred=Get-Credential
    PS C:\>Set-AADIntEASSettings -Credentials $Cred -DeviceId androidc481040056 -DeviceType Android -Model "Samsung S10" -PhoneNumber "+1234567890"   
#>
function Set-EASSettings
{
    Param(
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken,
            [Parameter(Mandatory=$True)]
            [String]$DeviceId,
            [Parameter(Mandatory=$False)]
            [String]$DeviceType="Android",
            [Parameter(Mandatory=$False)]
            [String]$Model,
            [Parameter(Mandatory=$False)]
            [String]$IMEI,
            [Parameter(Mandatory=$False)]
            [String]$FriendlyName,
            [Parameter(Mandatory=$False)]
            [String]$OS,
            [Parameter(Mandatory=$False)]
            [String]$OSLanguage,
            [Parameter(Mandatory=$False)]
            [String]$PhoneNumber,
            [Parameter(Mandatory=$False)]
            [String]$MobileOperator,
            [Parameter(Mandatory=$False)]
            [String]$UserAgent
        )
    Process
    {
        [xml]$request=@"
<Settings xmlns="Settings">
     <DeviceInformation>
         <Set>
             <Model>$Model</Model>
             <IMEI>$IMEI</IMEI>
             <FriendlyName>$FriendlyName</FriendlyName>
             <OS>$OS</OS>
             <OSLanguage>$OSLanguage</OSLanguage>
             <PhoneNumber>$PhoneNumber</PhoneNumber>
             <MobileOperator>$MobileOperator</MobileOperator>
             <UserAgent>$UserAgent</UserAgent>
         </Set>
     </DeviceInformation>
 </Settings>
"@

        $response = Call-EAS -Request $request -Command Settings -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType -UserAgent $UserAgent

        return $response.OuterXml
    }
}

<#
    .SYNOPSIS
    Adds a new ActiveSync device to user

    .DESCRIPTION
    Adds a new ActiveSync device to the user, and accepts security policies. All device information settings are required (Model, IMEI, FriendlyName, OS, OSLanguage, PhoneNumber, MobileOperator, and User-Agent).
    Returns a policy key that could be used in subsequent ActiveSync calls
    
    .Example
    PS C:\>$Cred=Get-Credential
    PS C:\>Add-AADIntEASDevice -Credentials $Cred -DeviceId androidc481040056 -DeviceType Android -Model "Samsung S10" -PhoneNumber "+1234567890" -IMEI "1234" -FriendlyName "My Phone" -OS "Android" -OSLanguage "EN" -MobileOperator "BT" -UserAgent "Android/8.0"

    3382976401
#>
function Add-EASDevice
{
    Param(
            [Parameter(ParameterSetName="Credentials",Mandatory=$True)]
            [System.Management.Automation.PSCredential]$Credentials,
            [Parameter(ParameterSetName="AccessToken",Mandatory=$True)]
            [String]$AccessToken,
            [Parameter(Mandatory=$True)]
            [String]$DeviceId,
            [Parameter(Mandatory=$False)]
            [String]$DeviceType="Android",
            [Parameter(Mandatory=$False)]
            [String]$Model,
            [Parameter(Mandatory=$False)]
            [String]$IMEI,
            [Parameter(Mandatory=$False)]
            [String]$FriendlyName,
            [Parameter(Mandatory=$False)]
            [String]$OS,
            [Parameter(Mandatory=$False)]
            [String]$OSLanguage,
            [Parameter(Mandatory=$False)]
            [String]$PhoneNumber,
            [Parameter(Mandatory=$False)]
            [String]$MobileOperator,
            [Parameter(Mandatory=$False)]
            [String]$UserAgent
        )
    Process
    {
        [xml]$request=@"
<Provision xmlns="Provision" >
     <DeviceInformation xmlns="Settings">
         <Set>
             <Model>$Model</Model>
             <IMEI>$IMEI</IMEI>
             <FriendlyName>$FriendlyName</FriendlyName>
             <OS>$OS</OS>
             <OSLanguage>$OSLanguage</OSLanguage>
             <PhoneNumber>$PhoneNumber</PhoneNumber>
             <MobileOperator>$MobileOperator</MobileOperator>
             <UserAgent>$UserAgent</UserAgent>
         </Set>
     </DeviceInformation>
      <Policies>
           <Policy>
                <PolicyType>MS-EAS-Provisioning-WBXML</PolicyType> 
           </Policy>
      </Policies>
 </Provision>

"@

        # The first request (must be done twice for some reason)
        $response = Call-EAS -Request $request -Command Provision -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType -UserAgent $UserAgent -PolicyKey 0 
        $response = Call-EAS -Request $request -Command Provision -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType -UserAgent $UserAgent -PolicyKey 0 

        # Save the temporary policy key
        $policyKey = $response.Provision.Policies.Policy.PolicyKey

        # Create a request to acknowledge the policy
[xml]$request=@"
<Provision xmlns="Provision" >
      <Policies>
           <Policy>
                <PolicyType>MS-EAS-Provisioning-WBXML</PolicyType> 
                <PolicyKey>$policyKey</PolicyKey>
                <Status>1</Status>
           </Policy>
      </Policies>
 </Provision>
"@

        # The second request
        $response = Call-EAS -Request $request -Command Provision -Authorization (Create-AuthorizationHeader -Credentials $Credentials -AccessToken $AccessToken) -DeviceId $DeviceId -DeviceType $DeviceType -UserAgent $UserAgent -PolicyKey $policyKey

        # Save the final policy key
        $policyKey = $response.Provision.Policies.Policy.PolicyKey
        
        $policyKey
    }
}