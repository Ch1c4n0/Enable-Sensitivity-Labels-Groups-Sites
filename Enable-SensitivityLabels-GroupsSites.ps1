#Requires -Version 7.0
<#
.SYNOPSIS
    Habilita Sensitivity Labels para Grupos e Sites no Microsoft Purview.

.DESCRIPTION
    Referencia:
    https://learn.microsoft.com/pt-br/purview/sensitivity-labels-teams-groups-sites#enable-this-preview-and-synchronize-labels

    Autentica via device code flow usando apenas Invoke-RestMethod (sem Microsoft.Graph SDK),
    evitando conflitos de versao da biblioteca MSAL no ambiente.

    Etapas:
      1. Obtem token via device code (https://microsoft.com/devicelogin)
      2. Habilita EnableMIPLabels = True no Entra ID via Graph REST API
      3. Conecta ao Security & Compliance PowerShell e executa Execute-AzureAdLabelSync

.NOTES
    Requer PowerShell 7+. Download: https://aka.ms/powershell
    Requer Administrador Global ou Compliance Administrator.
    Nao requer nenhum modulo do Microsoft.Graph SDK.
#>

[CmdletBinding()]
param (
    [Parameter(HelpMessage = "UPN do administrador. Usado como login hint no device code.")]
    [string]$AdminUPN
)

#region Helpers
function Write-Step { param([string]$M) Write-Host "`n[$([datetime]::Now.ToString('HH:mm:ss'))] $M" -ForegroundColor Cyan }
function Write-OK   { param([string]$M) Write-Host "  [OK]    $M" -ForegroundColor Green }
function Write-Fail { param([string]$M) Write-Host "  [ERRO]  $M" -ForegroundColor Red }
function Write-Info { param([string]$M) Write-Host "          $M" -ForegroundColor Gray }

# Chamada REST ao Microsoft Graph com o token obtido
function Invoke-Graph {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body = $null,
        [string]$Token
    )
    $headers = @{ Authorization = "Bearer $Token"; "Content-Type" = "application/json" }
    $params  = @{ Method = $Method; Uri = $Uri; Headers = $headers; ErrorAction = "Stop" }
    if ($Body) { $params["Body"] = ($Body | ConvertTo-Json -Depth 10 -Compress) }
    Invoke-RestMethod @params
}
#endregion

Write-Host "`n=== Habilitar Sensitivity Labels - Grupos e Sites ===" -ForegroundColor White

#region Modulo ExchangeOnlineManagement (unico modulo necessario)
Write-Step "Verificando ExchangeOnlineManagement"

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Info "Instalando ExchangeOnlineManagement..."
    Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
}
Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
Write-OK "ExchangeOnlineManagement importado."
#endregion

#region Device Code Flow (puro Invoke-RestMethod, sem Microsoft.Graph SDK)
Write-Step "Autenticando via device code (sem Microsoft.Graph SDK)"

# App publica "Microsoft Graph Command Line Tools" — nao requer client secret
$clientId  = "14d82eec-204b-4c2f-b7e8-296a70dab67e"
$tenantId  = "organizations"
$scope     = "https://graph.microsoft.com/Directory.ReadWrite.All offline_access"
$authBase  = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0"

try {
    # 1. Solicitar device code
    $dcBody = "client_id=$clientId&scope=$([uri]::EscapeDataString($scope))"
    if ($AdminUPN) { $dcBody += "&login_hint=$([uri]::EscapeDataString($AdminUPN))" }

    $dc = Invoke-RestMethod -Method POST -Uri "$authBase/devicecode" `
              -Body $dcBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop

    Write-Host ""
    Write-Host "  Acesse : $($dc.verification_uri)" -ForegroundColor Yellow
    Write-Host "  Codigo : $($dc.user_code)"        -ForegroundColor Yellow
    Write-Host ""
    Write-Info "Aguardando autenticacao (expira em $($dc.expires_in)s)..."

    # 2. Polling ate obter o token
    $token   = $null
    $expires = (Get-Date).AddSeconds($dc.expires_in)
    $interval= [int]$dc.interval

    while ((Get-Date) -lt $expires) {
        Start-Sleep -Seconds $interval
        try {
            $tkBody = "grant_type=urn:ietf:params:oauth:grant-type:device_code" +
                      "&client_id=$clientId&device_code=$($dc.device_code)"
            $tkResp = Invoke-RestMethod -Method POST -Uri "$authBase/token" `
                          -Body $tkBody -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
            $token = $tkResp.access_token
            break
        }
        catch {
            $err = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error
            if ($err -ne "authorization_pending") { throw }
        }
    }

    if (-not $token) { Write-Fail "Timeout: autenticacao nao concluida a tempo."; exit 1 }
    Write-OK "Autenticado com sucesso."
}
catch {
    Write-Fail "Falha na autenticacao: $_"
    exit 1
}
#endregion

#region EnableMIPLabels
Write-Step "Habilitando EnableMIPLabels no Entra ID"

try {
    $settings   = Invoke-Graph -Method GET -Uri "https://graph.microsoft.com/beta/settings" -Token $token
    $grpSetting = $settings.value | Where-Object { $_.displayName -eq "Group.Unified" }

    if (-not $grpSetting) {
        Write-Info "Configuracao 'Group.Unified' nao encontrada. Criando..."
        $templates = Invoke-Graph -Method GET -Uri "https://graph.microsoft.com/beta/directorySettingTemplates" -Token $token
        $template  = $templates.value | Where-Object { $_.displayName -eq "Group.Unified" }
        if (-not $template) { Write-Fail "Template 'Group.Unified' nao encontrado. Verifique permissoes."; exit 1 }

        Invoke-Graph -Method POST -Uri "https://graph.microsoft.com/beta/settings" `
            -Body @{ templateId = $template.id } -Token $token | Out-Null

        $settings   = Invoke-Graph -Method GET -Uri "https://graph.microsoft.com/beta/settings" -Token $token
        $grpSetting = $settings.value | Where-Object { $_.displayName -eq "Group.Unified" }
        Write-OK "Configuracao criada."
    }

    $current = ($grpSetting.values | Where-Object { $_.name -eq "EnableMIPLabels" }).value
    Write-Info "Valor atual: EnableMIPLabels = '$current'"

    if ($current -eq "True") {
        Write-OK "EnableMIPLabels ja esta habilitado."
    }
    else {
        $newValues = $grpSetting.values | ForEach-Object {
            @{ name = $_.name; value = if ($_.name -eq "EnableMIPLabels") { "True" } else { $_.value } }
        }
        Invoke-Graph -Method PATCH -Uri "https://graph.microsoft.com/beta/settings/$($grpSetting.id)" `
            -Body @{ values = $newValues } -Token $token

        $verify = Invoke-Graph -Method GET -Uri "https://graph.microsoft.com/beta/settings/$($grpSetting.id)" -Token $token
        $result = ($verify.values | Where-Object { $_.name -eq "EnableMIPLabels" }).value

        if ($result -eq "True") { Write-OK "EnableMIPLabels habilitado com sucesso!" }
        else { Write-Fail "Falha ao habilitar EnableMIPLabels. Valor: '$result'"; exit 1 }
    }
}
catch {
    Write-Fail "Erro ao configurar EnableMIPLabels: $_"
    exit 1
}
#endregion

#region Sync Labels
Write-Step "Conectando ao Security & Compliance PowerShell"

try {
    $ippParams = @{ ShowBanner = $false }
    if ($AdminUPN) { $ippParams["UserPrincipalName"] = $AdminUPN }
    Connect-IPPSSession @ippParams -ErrorAction Stop
    Write-OK "Conectado."
}
catch {
    Write-Fail "Falha ao conectar: $_"
    exit 1
}

Write-Step "Sincronizando labels (Execute-AzureAdLabelSync)"

try {
    Execute-AzureAdLabelSync -ErrorAction Stop
    Write-OK "Labels sincronizados com sucesso!"
}
catch {
    Write-Fail "Erro em Execute-AzureAdLabelSync: $_"
    exit 1
}
#endregion

Write-Host @"

=== CONCLUIDO ===
  [OK] EnableMIPLabels = True no Entra ID
  [OK] Labels sincronizados

  Aguarde ate 24h para os labels aparecerem nos grupos e sites.
  Proximos passos: https://purview.microsoft.com -> configure escopo "Groups & Sites"

"@ -ForegroundColor Green
