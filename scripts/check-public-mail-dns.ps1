param(
  [string]$Domain = "forgath.ru"
)

$ErrorActionPreference = "Stop"

function Get-DnsText {
  param(
    [string]$Name,
    [string]$Type
  )

  try {
    Resolve-DnsName -Name $Name -Type $Type -ErrorAction Stop
  } catch {
    Write-Host "[mail-dns] ${Name} ${Type}: lookup failed: $($_.Exception.Message)"
    return @()
  }
}

$mx = Get-DnsText -Name $Domain -Type MX
$txt = Get-DnsText -Name $Domain -Type TXT
$dmarcName = "_dmarc.$Domain"
$dmarc = Get-DnsText -Name $dmarcName -Type TXT
$mailHost = "mail.$Domain"
$mailA = Get-DnsText -Name $mailHost -Type A

Write-Host "[mail-dns] MX:"
$mx | Where-Object { $_.Type -eq "MX" } | ForEach-Object {
  Write-Host ("[mail-dns] {0} preference={1}" -f $_.NameExchange, $_.Preference)
}

Write-Host "[mail-dns] SPF:"
$spfRecords = @($txt | Where-Object { $_.Type -eq "TXT" -and ($_.Strings -join "") -like "v=spf1*" })
if ($spfRecords.Count -eq 0) {
  Write-Host "[mail-dns] SPF=MISSING"
} else {
  $spfRecords | ForEach-Object { Write-Host ("[mail-dns] SPF=SET length={0}" -f (($_.Strings -join "").Length)) }
}

Write-Host "[mail-dns] DMARC:"
$dmarcRecords = @($dmarc | Where-Object { $_.Type -eq "TXT" -and ($_.Strings -join "") -like "v=DMARC1*" })
if ($dmarcRecords.Count -eq 0) {
  Write-Host "[mail-dns] DMARC=MISSING"
} else {
  $dmarcRecords | ForEach-Object { Write-Host ("[mail-dns] DMARC=SET length={0}" -f (($_.Strings -join "").Length)) }
}

Write-Host "[mail-dns] $mailHost A:"
$mailA | Where-Object { $_.Type -eq "A" } | ForEach-Object {
  Write-Host ("[mail-dns] {0}" -f $_.IPAddress)
}
