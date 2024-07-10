param(
    [Parameter(Mandatory=$true)]
    [string]$email,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$password,

    [Parameter(Mandatory=$true)]
    [string]$to,
    
    [Parameter(Mandatory=$true)]
    [string]$subject,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$body,

    [Parameter(Mandatory=$true)]
    [ValidateSet("gmail", "outlook")]
    [string]$SMTP
);

[string]$from = $email;
[string]$user = $email;
[SecureString]$password = $password | ConvertTo-SecureString -AsPlainText -Force;
[string]$SMTP = "smtp.$SMTP.com";
[int]$SMTPPort = 587;

# Resolve Body file path
try {
    Write-Host "-- Looking for body text file..." -BackgroundColor Blue -ForegroundColor White;
    [string]$Path = $PSScriptRoot + "\" + $body;
    $body = Get-Content -Path $Path -Raw;
    Write-Host "-- File found at $Path" -BackgroundColor Blue -ForegroundColor White;
}catch {
    Write-Host "-- Body text file not found" -BackgroundColor DarkRed -ForegroundColor White;
    exit;
}

# Send email
try {
    Send-MailMessage -From $from -To $to -Subject $subject -Body $body -SmtpServer $SMTP -Port $SMTPPort -UseSsl -Credential (New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, $password);
    Write-Host "-- Mail sended successfully :D" -BackgroundColor DarkGreen -ForegroundColor White;
}catch {
    Write-Host "-- Error sending email" -BackgroundColor DarkRed -ForegroundColor White;
    exit;
}
