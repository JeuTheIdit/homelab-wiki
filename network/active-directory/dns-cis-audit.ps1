# ==========================================
# Windows DNS CIS Audit-Only Validation Script
# ==========================================

Write-Host "`n=== Windows DNS CIS Audit Report ===`n" -ForegroundColor Cyan

# ----------------
# VARIABLES
# ----------------
$ADZoneName = "home.jnbolsen.com"
$ExpectedForwarders = @("1.1.1.1", "1.0.0.1")
$InternalIPs = @("192.168.1.10")

# ----------------
# Helper function
# ----------------
function Test-Result {
    param ($Condition, $PassMsg, $FailMsg)
    if ($Condition) {
        Write-Host "[PASS] $PassMsg" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $FailMsg" -ForegroundColor Red
    }
}

# ======================================================
# CIS LEVEL 1 CHECKS
# ======================================================

Write-Host "`n--- CIS Level 1 Checks ---`n" -ForegroundColor Yellow

# CIS 18.9.3.1 - Root hints disabled
$RootHints = Get-DnsServerRootHint -ErrorAction SilentlyContinue
Test-Result ($RootHints.Count -eq 0) `
    "Root hints are disabled." `
    "Root hints are ENABLED."

# CIS 18.9.3.2 - DNS forwarders configured
$Forwarders = (Get-DnsServerForwarder -ErrorAction SilentlyContinue).IPAddress
Test-Result ($Forwarders -ne $null) `
    "DNS forwarders are configured: $($Forwarders -join ', ')" `
    "DNS forwarders are NOT configured."

# CIS 18.9.3.2 (Optional strict match)
$ForwarderMatch = @($ExpectedForwarders | Where-Object { $_ -in $Forwarders }).Count -eq $ExpectedForwarders.Count
Test-Result $ForwarderMatch `
    "DNS forwarders match expected values." `
    "DNS forwarders do NOT match expected values."

# CIS 18.9.3.3 - Secure dynamic updates
$Zone = Get-DnsServerZone -Name $ADZoneName -ErrorAction SilentlyContinue
Test-Result ($Zone.DynamicUpdate -eq "Secure") `
    "Zone '$ADZoneName' uses secure dynamic updates." `
    "Zone '$ADZoneName' does NOT use secure dynamic updates."

# CIS 18.9.3.4 - Zone transfers disabled
$ZoneTransfersDisabled = ($Zone.ZoneTransfer -eq "None")
Test-Result $ZoneTransfersDisabled `
    "Zone transfers are disabled." `
    "Zone transfers are ENABLED."

# CIS 18.9.3.5 - Listening interfaces restricted
$ListenIPs = (Get-DnsServerSetting -All).ListenAddresses
$ListeningRestricted = @($ListenIPs | Where-Object { $_ -in $InternalIPs }).Count -gt 0
Test-Result $ListeningRestricted `
    "DNS listening interfaces are restricted." `
    "DNS is listening on ALL interfaces."

# CIS 18.9.3.6 - DNS event logging enabled
$Diagnostics = Get-DnsServerDiagnostics
Test-Result ($Diagnostics.EventLogLevel -ge 4) `
    "DNS event logging is enabled." `
    "DNS event logging is NOT enabled."

# ======================================================
# CIS LEVEL 2 CHECKS
# ======================================================

Write-Host "`n--- CIS Level 2 Checks ---`n" -ForegroundColor Yellow

# CIS 18.9.3.7 - Response Rate Limiting
$RRL = Get-DnsServerResponseRateLimiting -ErrorAction SilentlyContinue
Test-Result ($RRL -ne $null) `
    "DNS Response Rate Limiting is enabled." `
    "DNS Response Rate Limiting is NOT enabled."

# CIS 18.9.3.8 - DNSSEC validation
$DnsSec = Get-DnsServerDnsSecZoneSetting -ErrorAction SilentlyContinue
Test-Result ($DnsSec.EnableValidation -eq $true) `
    "DNSSEC validation is enabled." `
    "DNSSEC validation is NOT enabled."

# CIS 18.9.3.9 - Recursion scopes
$Scopes = Get-DnsServerRecursionScope -ErrorAction SilentlyContinue
Test-Result ($Scopes.Count -gt 0) `
    "DNS recursion scopes are configured." `
    "DNS recursion scopes are NOT configured."

# CIS 18.9.3.9 - Query resolution policies
$Policies = Get-DnsServerQueryResolutionPolicy -ErrorAction SilentlyContinue
Test-Result ($Policies.Count -gt 0) `
    "DNS query resolution policies are present." `
    "DNS query resolution policies are NOT present."

Write-Host "`n=== DNS CIS Audit Complete ===`n" -ForegroundColor Cyan
