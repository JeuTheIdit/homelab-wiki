# ================================
# Windows DNS CIS Hardening Script
# Levels: 1 and 2
# ================================

Write-Host "Starting Windows DNS CIS hardening..." -ForegroundColor Cyan

# ----------------
# VARIABLES
# ----------------
$Forwarders = @("1.1.1.1", "8.8.8.8") # Or Quad9 9.9.9.9 for malware blocking
$ADZoneName = "home.jnbolsen.com"
$InternalIPs = @("192.168.60.203") # DNS/DC IP(s)

# ----------------
# CIS 18.9.3.1 (L1)
# Disable Root Hints
# ----------------
Write-Host "Disabling DNS root hints..."
Get-DnsServerRootHint | Remove-DnsServerRootHint -Force

# ----------------
# CIS 18.9.3.2 (L1)
# Configure DNS Forwarders
# ----------------
Write-Host "Configuring DNS forwarders..."
Set-DnsServerForwarder -IPAddress $Forwarders -UseRootHint $false

# ----------------
# CIS 18.9.3.3 (L1)
# Secure Dynamic Updates
# ----------------
Write-Host "Enforcing secure dynamic updates..."
Set-DnsServerZone -Name $ADZoneName -DynamicUpdate Secure

# ----------------
# CIS 18.9.3.4 (L1)
# Disable Zone Transfers
# ----------------
Write-Host "Disabling zone transfers..."
Set-DnsServerZoneTransferPolicy -Name $ADZoneName -TransferType None

# ----------------
# CIS 18.9.3.5 (L1)
# Limit DNS Listening Interfaces
# ----------------
Write-Host "Restricting DNS listening interfaces..."
Set-DnsServerSetting -ListenAddresses $InternalIPs

# ----------------
# CIS 18.9.3.6 (L1)
# Enable DNS Event Logging
# ----------------
Write-Host "Enabling DNS event logging..."
Set-DnsServerDiagnostics -EventLogLevel 4

# ======================================================
# =================== LEVEL 2 ==========================
# ======================================================

# ----------------
# CIS 18.9.3.7 (L2)
# Enable DNS Response Rate Limiting
# ----------------
Write-Host "Enabling DNS Response Rate Limiting (RRL)..."
Add-DnsServerResponseRateLimiting -ErrorAction SilentlyContinue

# ----------------
# CIS 18.9.3.8 (L2)
# Enable DNSSEC Validation
# ----------------
Write-Host "Enabling DNSSEC validation..."
Set-DnsServerDnsSecZoneSetting -EnableValidation $true

# ----------------
# CIS 18.9.3.9 (L2)
# Restrict Recursion to Internal Interfaces
# ----------------
Write-Host "Restricting recursion scope..."

if (-not (Get-DnsServerRecursionScope -Name "Internal" -ErrorAction SilentlyContinue)) {
    Add-DnsServerRecursionScope -Name "Internal" -EnableRecursion $true
}

Add-DnsServerQueryResolutionPolicy `
    -Name "AllowInternalRecursion" `
    -Action ALLOW `
    -RecursionScope "Internal" `
    -ClientSubnet "InternalSubnet" `
    -ErrorAction SilentlyContinue

if (-not (Get-DnsServerClientSubnet -Name "InternalSubnet" -ErrorAction SilentlyContinue)) {
    Add-DnsServerClientSubnet -Name "InternalSubnet" -IPv4Subnet "192.168.0.0/16"
}

Write-Host "DNS CIS hardening complete." -ForegroundColor Green
