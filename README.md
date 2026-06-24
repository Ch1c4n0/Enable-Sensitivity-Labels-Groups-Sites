<h1 align="center">Enable Sensitivity Labels - Groups &amp; Sites</h1>

<p align="center">
  <a href="#-portugu%C3%AAs"><img src="https://img.shields.io/badge/lang-Portugu%C3%AAs-009c3b?style=for-the-badge" alt="Português"></a>
  <a href="#-english"><img src="https://img.shields.io/badge/lang-English-002868?style=for-the-badge" alt="English"></a>
</p>

---

## 🇧🇷 Português

### 📌 Visão Geral

Este repositório contém um script **PowerShell 7** que **habilita os Sensitivity Labels (Rótulos de Confidencialidade) para Grupos e Sites** no **Microsoft Purview** / **Microsoft Entra ID**. O script autentica via **device code flow** usando apenas `Invoke-RestMethod` — **sem o Microsoft.Graph SDK** — para evitar conflitos de versão da biblioteca MSAL no ambiente.

> Referência oficial: [Sensitivity labels for Teams, Groups & Sites](https://learn.microsoft.com/pt-br/purview/sensitivity-labels-teams-groups-sites#enable-this-preview-and-synchronize-labels)

### 📂 Script

| Arquivo | Descrição |
|---------|----------|
| `Enable-SensitivityLabels-GroupsSites.ps1` | Habilita `EnableMIPLabels` no Entra ID e sincroniza os labels no Security &amp; Compliance. |

### ⚙️ O que o script faz

1. **Verifica/instala** o módulo `ExchangeOnlineManagement` (único módulo necessário).
2. **Autentica via device code** (https://microsoft.com/devicelogin) usando o app público *Microsoft Graph Command Line Tools* — sem client secret.
3. **Habilita `EnableMIPLabels = True`** na configuração `Group.Unified` do Entra ID via Graph REST API (criando a configuração a partir do template, se necessário).
4. **Conecta ao Security &amp; Compliance PowerShell** (`Connect-IPPSSession`).
5. **Executa `Execute-AzureAdLabelSync`** para sincronizar os labels para grupos e sites.

### ▶️ Como usar

```powershell
# Requer PowerShell 7+  (https://aka.ms/powershell)

# Opcional: informar o UPN do admin como login hint
.\Enable-SensitivityLabels-GroupsSites.ps1 -AdminUPN admin@suaempresa.com

# Ou simplesmente:
.\Enable-SensitivityLabels-GroupsSites.ps1
```

### ✅ Pré-requisitos

- **PowerShell 7+**.
- Permissões de **Administrador Global** ou **Compliance Administrator**.
- Módulo **ExchangeOnlineManagement** (instalado automaticamente, se ausente).
- **Não** requer o Microsoft.Graph SDK.

> ⚠️ Após a execução, aguarde até **24 horas** para os labels aparecerem nos grupos e sites. Em seguida, configure o escopo *"Groups &amp; Sites"* em https://purview.microsoft.com.

---

## 🇺🇸 English

### 📌 Overview

This repository contains a **PowerShell 7** script that **enables Sensitivity Labels for Groups and Sites** in **Microsoft Purview** / **Microsoft Entra ID**. The script authenticates via **device code flow** using only `Invoke-RestMethod` — **without the Microsoft.Graph SDK** — to avoid MSAL library version conflicts in the environment.

> Official reference: [Sensitivity labels for Teams, Groups & Sites](https://learn.microsoft.com/purview/sensitivity-labels-teams-groups-sites#enable-this-preview-and-synchronize-labels)

### 📂 Script

| File | Description |
|------|-------------|
| `Enable-SensitivityLabels-GroupsSites.ps1` | Enables `EnableMIPLabels` in Entra ID and synchronizes labels in Security &amp; Compliance. |

### ⚙️ What the script does

1. **Checks/installs** the `ExchangeOnlineManagement` module (the only required module).
2. **Authenticates via device code** (https://microsoft.com/devicelogin) using the public *Microsoft Graph Command Line Tools* app — no client secret.
3. **Enables `EnableMIPLabels = True`** on the Entra ID `Group.Unified` setting via Graph REST API (creating the setting from the template if needed).
4. **Connects to Security &amp; Compliance PowerShell** (`Connect-IPPSSession`).
5. **Runs `Execute-AzureAdLabelSync`** to synchronize labels to groups and sites.

### ▶️ How to use

```powershell
# Requires PowerShell 7+  (https://aka.ms/powershell)

# Optional: pass the admin UPN as a login hint
.\Enable-SensitivityLabels-GroupsSites.ps1 -AdminUPN admin@yourcompany.com

# Or simply:
.\Enable-SensitivityLabels-GroupsSites.ps1
```

### ✅ Requirements

- **PowerShell 7+**.
- **Global Administrator** or **Compliance Administrator** permissions.
- **ExchangeOnlineManagement** module (auto-installed if missing).
- Does **not** require the Microsoft.Graph SDK.

> ⚠️ After running, allow up to **24 hours** for the labels to appear on groups and sites. Then configure the *"Groups &amp; Sites"* scope at https://purview.microsoft.com.

---

<p align="center">Made with ❤️ by <a href="https://github.com/Ch1c4n0">Marcelo dos Santos Gonçalves</a></p>
