#Requires -Version 5.1
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Runtime.WindowsRuntime

[System.Windows.Forms.Application]::EnableVisualStyles()

# ---------------------------------------------------------------------------
# WinRT bootstrap
# ---------------------------------------------------------------------------
$script:asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object { $_.Name -eq 'AsTask' -and
                   $_.GetParameters().Count -eq 1 -and
                   $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]

function Await-WinRT ($WinRtTask, $ResultType) {
    if ($null -eq $script:asTaskGeneric) {
        $script:asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
            Where-Object { $_.Name -eq 'AsTask' -and
                           $_.GetParameters().Count -eq 1 -and
                           $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    }
    $asTask  = $script:asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    while (-not $netTask.IsCompleted) {
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(30)
    }
    if ($netTask.IsFaulted) { throw $netTask.Exception.InnerException }
    $netTask.Result
}

[Windows.Networking.Connectivity.NetworkInformation,           Windows.Networking.Connectivity,       ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.NetworkOperators.NetworkOperatorTetheringAccessPointConfiguration, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult,          Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null
[Windows.Networking.NetworkOperators.TetheringOperationalState, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime] | Out-Null

# ---------------------------------------------------------------------------
# API & State
# ---------------------------------------------------------------------------
$script:clientFirstSeen       = @{}
$script:hotspotStartTime      = $null
$script:autoResumeWanted      = $true   # True: user wants hotspot running whenever WAN is available
$script:wasRunningBeforeSleep = $false  # True: hotspot was active right before sleep
$script:isSleeping            = $false  # True: currently suspended/sleeping
$script:lastWanProfile        = $null

function Format-Bytes ([long]$bytes) {
    if ($bytes -ge 1GB) { return "{0:N2} GB" -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return "{0:N2} MB" -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return "{0:N2} KB" -f ($bytes / 1KB) }
    return "$bytes B"
}

function Get-HotspotStatus {
    try {
        $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
        if ($null -eq $profile) {
            $srcDesc = if ($script:autoResumeWanted) { 'Disconnected (Auto-start on WAN UP)' } else { 'No internet connection' }
            return @{ State='Off'; Ssid=''; Pass=''; Source=$srcDesc; Clients=@(); Traffic='-' }
        }
        $mgr  = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
        $cfg  = $mgr.GetCurrentAccessPointConfiguration()
        $state = $mgr.TetheringOperationalState.ToString()

        if ($state -eq 'On') {
            if ($null -eq $script:hotspotStartTime) { $script:hotspotStartTime = Get-Date }
        } else {
            $script:hotspotStartTime = $null
            $script:clientFirstSeen.Clear()
        }

        $rawClients = $mgr.GetTetheringClients()
        $currentMacs = @{}
        $list = @()
        $now = Get-Date

        foreach ($c in $rawClients) {
            $mac = $c.MacAddress
            $currentMacs[$mac] = $true
            if (-not $script:clientFirstSeen.ContainsKey($mac)) {
                $script:clientFirstSeen[$mac] = $now
            }
            $dur = $now - $script:clientFirstSeen[$mac]
            $durStr = if ($dur.TotalHours -ge 1) {
                "{0:D2}h {1:D2}m" -f [int]$dur.TotalHours, $dur.Minutes
            } elseif ($dur.TotalMinutes -ge 1) {
                "{0:D2}m {1:D2}s" -f [int]$dur.TotalMinutes, $dur.Seconds
            } else {
                "{0:D2}s" -f [int]$dur.TotalSeconds
            }

            $hn = if ($c.HostNames.Count -gt 0) { $c.HostNames[0].CanonicalName } else { 'Unknown' }
            $list += [PSCustomObject]@{ Mac=$mac; Host=$hn; Duration=$durStr }
        }

        # Clean up disconnected MACs from tracking hashtable
        $toRemove = @()
        foreach ($k in $script:clientFirstSeen.Keys) {
            if (-not $currentMacs.ContainsKey($k)) { $toRemove += $k }
        }
        foreach ($k in $toRemove) { $script:clientFirstSeen.Remove($k) }

        # Get Virtual Adapter Traffic Stats if available
        $trafficStr = '-'
        try {
            $stat = Get-NetAdapterStatistics -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*Wi-Fi Direct*" -or $_.Name -like "*本地*" } | Select-Object -First 1
            if ($null -ne $stat) {
                $trafficStr = "v: $(Format-Bytes $stat.ReceivedBytes) / ^: $(Format-Bytes $stat.SentBytes)"
            }
        } catch {}

        return @{
            State   = $state
            Ssid    = $cfg.Ssid
            Pass    = $cfg.Passphrase
            Source  = $profile.ProfileName
            Clients = $list
            Traffic = $trafficStr
        }
    } catch {
        return @{ State='Error'; Ssid=''; Pass=''; Source=$_.Exception.Message; Clients=@(); Traffic='-' }
    }
}

function Invoke-HotspotAction ([string]$Action) {
    try {
        $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
        if ($null -eq $profile) { return "No active internet connection profile found." }
        $mgr = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
        if ($Action -eq 'Start') {
            $res = Await-WinRT ($mgr.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
            if ($res.Status.ToString() -ne 'Success') {
                return "Failed to start hotspot: Status = $($res.Status), Error = $($res.AdditionalErrorMessage)"
            }
        } elseif ($Action -eq 'Stop') {
            $res = Await-WinRT ($mgr.StopTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
            if ($res.Status.ToString() -ne 'Success') {
                return "Failed to stop hotspot: Status = $($res.Status), Error = $($res.AdditionalErrorMessage)"
            }
        }
        return $null
    } catch {
        return "Error executing ${Action}: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Tray icon (GDI+)
# ---------------------------------------------------------------------------
function New-TrayIcon ([string]$State) {
    $bmp = New-Object System.Drawing.Bitmap 32,32
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)
    $color = switch ($State) {
        'On'      { [System.Drawing.Color]::FromArgb(34,197,94)  }
        'Busy'    { [System.Drawing.Color]::FromArgb(251,191,36) }
        'Waiting' { [System.Drawing.Color]::FromArgb(251,191,36) }
        default   { [System.Drawing.Color]::FromArgb(107,114,128)}
    }
    $pen = New-Object System.Drawing.Pen $color, 2.5
    $cx=16; $cy=20
    foreach ($r in @(12,8,4)) { $g.DrawArc($pen,($cx-$r),($cy-$r),($r*2),($r*2),210,120) }
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillEllipse($brush,$cx-2,$cy-2,4,4)
    $pen.Dispose(); $brush.Dispose(); $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

# ---------------------------------------------------------------------------
# Colors / Fonts
# ---------------------------------------------------------------------------
$C = @{
    BG     = [System.Drawing.Color]::FromArgb(15,  23, 42)
    Card   = [System.Drawing.Color]::FromArgb(30,  41, 59)
    Green  = [System.Drawing.Color]::FromArgb(34, 197, 94)
    Red    = [System.Drawing.Color]::FromArgb(248,113,113)
    RedBtn = [System.Drawing.Color]::FromArgb(239, 68, 68)
    Yellow = [System.Drawing.Color]::FromArgb(251,191, 36)
    Text   = [System.Drawing.Color]::FromArgb(241,245,249)
    Sub    = [System.Drawing.Color]::FromArgb(148,163,184)
    Sep    = [System.Drawing.Color]::FromArgb( 51, 65, 85)
    White  = [System.Drawing.Color]::White
    Tr     = [System.Drawing.Color]::Transparent
}

$fntTitle    = [System.Drawing.Font]::new('Segoe UI', 13, [System.Drawing.FontStyle]::Bold)
$fntBold     = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Bold)
$fntNormal   = New-Object System.Drawing.Font 'Segoe UI', 9
$fntSmall    = New-Object System.Drawing.Font 'Segoe UI', 8
$fntMono     = New-Object System.Drawing.Font 'Consolas', 8.5
$fntDot      = New-Object System.Drawing.Font 'Wingdings', 14
$fntMenuBold = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)

# ---------------------------------------------------------------------------
# Form  (DPI-aware, resizable)
# ---------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text            = 'Hotspot Manager'
$form.ClientSize      = New-Object System.Drawing.Size 390, 500
$form.MinimumSize     = New-Object System.Drawing.Size 320, 420
$form.StartPosition   = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox     = $false
$form.BackColor       = $C.BG
$form.ShowInTaskbar   = $false
$form.Visible         = $false
$form.AutoScaleMode       = [System.Windows.Forms.AutoScaleMode]::Dpi
$form.AutoScaleDimensions = New-Object System.Drawing.SizeF 96.0, 96.0

# ---------------------------------------------------------------------------
# Outer TableLayoutPanel
# ---------------------------------------------------------------------------
$outer = New-Object System.Windows.Forms.TableLayoutPanel
$outer.Dock        = [System.Windows.Forms.DockStyle]::Fill
$outer.BackColor   = $C.BG
$outer.ColumnCount = 1
$outer.Padding     = New-Object System.Windows.Forms.Padding 14,10,14,10

$RS = [System.Windows.Forms.RowStyle]
$ST = [System.Windows.Forms.SizeType]
$outer.RowCount = 8
$outer.RowStyles.Add((New-Object $RS $ST::Absolute, 56)) | Out-Null  # 0 title
$outer.RowStyles.Add((New-Object $RS $ST::Absolute,  1)) | Out-Null  # 1 sep
$outer.RowStyles.Add((New-Object $RS $ST::Absolute,116)) | Out-Null  # 2 status card
$outer.RowStyles.Add((New-Object $RS $ST::Absolute, 48)) | Out-Null  # 3 toggle btn
$outer.RowStyles.Add((New-Object $RS $ST::Absolute, 24)) | Out-Null  # 4 refresh btn
$outer.RowStyles.Add((New-Object $RS $ST::Absolute,  1)) | Out-Null  # 5 sep
$outer.RowStyles.Add((New-Object $RS $ST::Absolute, 20)) | Out-Null  # 6 "CONNECTED" label
$outer.RowStyles.Add((New-Object $RS $ST::Percent, 100)) | Out-Null  # 7 listview
$form.Controls.Add($outer)

function Add-To ($ctrl, $row, [int]$marginT=0, [int]$marginB=0) {
    $ctrl.Margin = New-Object System.Windows.Forms.Padding 0,$marginT,0,$marginB
    $outer.Controls.Add($ctrl, 0, $row)
}

# ── Row 0: Title ─────────────────────────────────────────────────────────────
$pTitle           = New-Object System.Windows.Forms.Panel
$pTitle.Dock      = [System.Windows.Forms.DockStyle]::Fill
$pTitle.BackColor = $C.Tr

$lblTitle           = New-Object System.Windows.Forms.Label
$lblTitle.Text      = 'Hotspot Manager'
$lblTitle.Font      = $fntTitle
$lblTitle.ForeColor = $C.Text
$lblTitle.BackColor = $C.Tr
$lblTitle.AutoSize  = $true
$lblTitle.Location  = New-Object System.Drawing.Point 0, 2

$lblSub           = New-Object System.Windows.Forms.Label
$lblSub.Text      = 'Windows Mobile Hotspot Control Panel'
$lblSub.Font      = $fntSmall
$lblSub.ForeColor = $C.Sub
$lblSub.BackColor = $C.Tr
$lblSub.AutoSize  = $true
$lblSub.Location  = New-Object System.Drawing.Point 0, 36

$pTitle.Controls.AddRange(@($lblTitle, $lblSub))
Add-To $pTitle 0

# ── Row 1: Separator ─────────────────────────────────────────────────────────
$sep1 = New-Object System.Windows.Forms.Panel
$sep1.Dock = [System.Windows.Forms.DockStyle]::Fill; $sep1.BackColor = $C.Sep
Add-To $sep1 1

# ── Row 2: Status Card ───────────────────────────────────────────────────────
$card           = New-Object System.Windows.Forms.Panel
$card.Dock      = [System.Windows.Forms.DockStyle]::Fill
$card.BackColor = $C.Card
$card.Padding   = New-Object System.Windows.Forms.Padding 10,8,10,6

$pState             = New-Object System.Windows.Forms.FlowLayoutPanel
$pState.Dock        = [System.Windows.Forms.DockStyle]::Top
$pState.BackColor   = $C.Tr
$pState.FlowDirection = [System.Windows.Forms.FlowDirection]::LeftToRight
$pState.WrapContents= $false
$pState.AutoSize    = $true
$pState.Margin      = New-Object System.Windows.Forms.Padding 0,0,0,4

$lblDot           = New-Object System.Windows.Forms.Label
$lblDot.Text      = 'l'   # Wingdings circle
$lblDot.Font      = $fntDot
$lblDot.ForeColor = $C.Red
$lblDot.BackColor = $C.Tr
$lblDot.AutoSize  = $true
$lblDot.Margin    = New-Object System.Windows.Forms.Padding 0,1,4,0

$lblState           = New-Object System.Windows.Forms.Label
$lblState.Text      = 'Off'
$lblState.Font      = $fntBold
$lblState.ForeColor = $C.Red
$lblState.BackColor = $C.Tr
$lblState.AutoSize  = $true
$lblState.Margin    = New-Object System.Windows.Forms.Padding 0,2,0,0

$lblClients           = New-Object System.Windows.Forms.Label
$lblClients.Text      = '   0 devices connected'
$lblClients.Font      = $fntSmall
$lblClients.ForeColor = $C.Sub
$lblClients.BackColor = $C.Tr
$lblClients.AutoSize  = $true
$lblClients.Margin    = New-Object System.Windows.Forms.Padding 6,4,0,0

$pState.Controls.AddRange(@($lblDot, $lblState, $lblClients))

$infoGrid             = New-Object System.Windows.Forms.TableLayoutPanel
$infoGrid.Dock        = [System.Windows.Forms.DockStyle]::Fill
$infoGrid.BackColor   = $C.Tr
$infoGrid.ColumnCount = 2
$infoGrid.RowCount    = 3
$CS = [System.Windows.Forms.ColumnStyle]
$infoGrid.ColumnStyles.Add((New-Object $CS $ST::AutoSize))    | Out-Null
$infoGrid.ColumnStyles.Add((New-Object $CS $ST::Percent, 100))| Out-Null
for ($i=0;$i -lt 3;$i++) { $infoGrid.RowStyles.Add((New-Object $RS $ST::Percent, 33)) | Out-Null }

function Add-InfoRow2 ($label, $row) {
    $lKey           = New-Object System.Windows.Forms.Label
    $lKey.Text      = $label
    $lKey.Font      = $fntSmall
    $lKey.ForeColor = $C.Sub
    $lKey.BackColor = $C.Tr
    $lKey.AutoSize  = $true
    $lKey.Anchor    = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top
    $lKey.Margin    = New-Object System.Windows.Forms.Padding 0,2,8,0

    $lVal           = New-Object System.Windows.Forms.Label
    $lVal.Font      = if ($label -eq 'Password:') { $fntBold } else { $fntNormal }
    $lVal.ForeColor = $C.Text
    $lVal.BackColor = $C.Tr
    $lVal.AutoSize  = $true
    $lVal.Anchor    = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Top
    $lVal.Margin    = New-Object System.Windows.Forms.Padding 0,2,0,0

    $infoGrid.Controls.Add($lKey, 0, $row)
    $infoGrid.Controls.Add($lVal, 1, $row)
    return $lVal
}
$lblSrcVal  = Add-InfoRow2 'Source:'   0
$lblSsidVal = Add-InfoRow2 'SSID:'     1
$lblPassVal = Add-InfoRow2 'Password:' 2

$card.Controls.Add($infoGrid)
$card.Controls.Add($pState)
Add-To $card 2 4 4

# ── Row 3: Toggle button ──────────────────────────────────────────────────────
$btnToggle           = New-Object System.Windows.Forms.Button
$btnToggle.Text      = 'Start Hotspot'
$btnToggle.Font      = $fntBold
$btnToggle.ForeColor = $C.White
$btnToggle.BackColor = $C.Green
$btnToggle.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnToggle.FlatAppearance.BorderSize = 0
$btnToggle.Dock      = [System.Windows.Forms.DockStyle]::Fill
$btnToggle.Cursor    = [System.Windows.Forms.Cursors]::Hand
Add-To $btnToggle 3 2 2

# ── Row 4: Refresh (subtle text button) ──────────────────────────────────────
$btnRefresh           = New-Object System.Windows.Forms.Button
$btnRefresh.Text      = 'Refresh Status'
$btnRefresh.Font      = $fntSmall
$btnRefresh.ForeColor = $C.Sub
$btnRefresh.BackColor = $C.BG
$btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefresh.FlatAppearance.BorderSize         = 0
$btnRefresh.FlatAppearance.MouseOverBackColor = $C.Card
$btnRefresh.FlatAppearance.MouseDownBackColor = $C.Sep
$btnRefresh.Dock      = [System.Windows.Forms.DockStyle]::Fill
$btnRefresh.Cursor    = [System.Windows.Forms.Cursors]::Hand
Add-To $btnRefresh 4

# ── Row 5: Separator ─────────────────────────────────────────────────────────
$sep2 = New-Object System.Windows.Forms.Panel
$sep2.Dock = [System.Windows.Forms.DockStyle]::Fill; $sep2.BackColor = $C.Sep
Add-To $sep2 5

# ── Row 6: Connected Devices label ───────────────────────────────────────────
$lblDevHead           = New-Object System.Windows.Forms.Label
$lblDevHead.Text      = 'CONNECTED DEVICES'
$lblDevHead.Font      = $fntSmall
$lblDevHead.ForeColor = $C.Sub
$lblDevHead.BackColor = $C.Tr
$lblDevHead.Dock      = [System.Windows.Forms.DockStyle]::Fill
$lblDevHead.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
Add-To $lblDevHead 6

# ── Row 7: ListView (fills remaining height) ──────────────────────────────────
$listView               = New-Object System.Windows.Forms.ListView
$listView.View          = [System.Windows.Forms.View]::Details
$listView.FullRowSelect = $true
$listView.GridLines     = $false
$listView.BackColor     = $C.Card
$listView.ForeColor     = $C.Text
$listView.Font          = $fntMono
$listView.BorderStyle   = [System.Windows.Forms.BorderStyle]::None
$listView.HeaderStyle   = [System.Windows.Forms.ColumnHeaderStyle]::Nonclickable
$listView.Dock          = [System.Windows.Forms.DockStyle]::Fill
$null = $listView.Columns.Add('Hostname',       130)
$null = $listView.Columns.Add('IP Address',     100)
$null = $listView.Columns.Add('MAC Address',    110)
$null = $listView.Columns.Add('Connected Time', 80)
Add-To $listView 7

# ---------------------------------------------------------------------------
# Configuration Persistence ($env:LOCALAPPDATA\HotspotManager\config.json)
# ---------------------------------------------------------------------------
$cfgFile = Join-Path $env:LOCALAPPDATA 'HotspotManager\config.json'

function Save-Config {
    try {
        $dir = Split-Path $cfgFile
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        $cfgData = @{
            Width  = $form.ClientSize.Width
            Height = $form.ClientSize.Height
            Col0   = $listView.Columns[0].Width
            Col1   = $listView.Columns[1].Width
            Col2   = $listView.Columns[2].Width
            Col3   = $listView.Columns[3].Width
        }
        $cfgData | ConvertTo-Json | Set-Content -Path $cfgFile -Encoding UTF8 -Force
    } catch {}
}

function Load-Config {
    try {
        if (Test-Path $cfgFile) {
            $json = (Get-Content -Path $cfgFile -Raw -Encoding UTF8) | ConvertFrom-Json
            if ($null -ne $json.Width -and $json.Width -ge 320 -and $json.Height -ge 400) {
                $form.ClientSize = New-Object System.Drawing.Size $json.Width, $json.Height
            }
            if ($null -ne $json.Col0 -and $json.Col0 -gt 0) { $listView.Columns[0].Width = $json.Col0 }
            if ($null -ne $json.Col1 -and $json.Col1 -gt 0) { $listView.Columns[1].Width = $json.Col1 }
            if ($null -ne $json.Col2 -and $json.Col2 -gt 0) { $listView.Columns[2].Width = $json.Col2 }
            if ($null -ne $json.Col3 -and $json.Col3 -gt 0) { $listView.Columns[3].Width = $json.Col3 }
        }
    } catch {}
}

Load-Config

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
$script:isBusy     = $false
$script:lastStatus = @{ State='Off'; Ssid=''; Pass=''; Source=''; Clients=@() }

# ---------------------------------------------------------------------------
# Update tray icon + context menu state
# ---------------------------------------------------------------------------
function Update-Tray {
    $s     = $script:lastStatus
    $state = $s.State
    $cnt   = $s.Clients.Count
    
    $trayIconState = if ($state -eq 'On') { 'On' } elseif ($script:autoResumeWanted -and $null -eq [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()) { 'Waiting' } else { 'Off' }
    $script:notifyIcon.Icon = New-TrayIcon $trayIconState

    $devStr = if ($cnt -gt 0) { " ($cnt connected)" } else { '' }
    $statusText = if ($state -eq 'On') { "Hotspot: On$devStr" } elseif ($trayIconState -eq 'Waiting') { "Hotspot: Waiting for WAN..." } else { "Hotspot: Off" }
    $script:notifyIcon.Text = $statusText

    if ($null -ne $script:miStart) {
        $script:miStart.Enabled = ($state -ne 'On')
        $script:miStop.Enabled  = ($state -eq 'On')
    }
}

# ---------------------------------------------------------------------------
# Update form UI (only called when form is visible)
# ---------------------------------------------------------------------------
function Update-FormUI {
    $s = $script:lastStatus
    $state = $s.State
    $isWaitingWan = ($state -ne 'On' -and $script:autoResumeWanted -and ($null -eq [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()))

    if ($state -eq 'On') {
        $lblDot.ForeColor    = $C.Green
        $lblState.Text       = 'On'
        $lblState.ForeColor  = $C.Green
        $btnToggle.Text      = 'Stop Hotspot'
        $btnToggle.BackColor = $C.RedBtn
    } elseif ($isWaitingWan) {
        $lblDot.ForeColor    = $C.Yellow
        $lblState.Text       = 'Off (Waiting for WAN)'
        $lblState.ForeColor  = $C.Yellow
        $btnToggle.Text      = 'Stop Auto-Resume'
        $btnToggle.BackColor = $C.RedBtn
    } else {
        $lblDot.ForeColor    = $C.Red
        $lblState.Text       = 'Off'
        $lblState.ForeColor  = $C.Red
        $btnToggle.Text      = 'Start Hotspot'
        $btnToggle.BackColor = $C.Green
    }

    $cnt = $s.Clients.Count
    $lblClients.Text  = "   $cnt device$(if($cnt -ne 1){'s'}) connected"
    $lblSrcVal.Text   = if ($s.Source) { $s.Source } else { '-' }
    $lblSsidVal.Text  = if ($s.Ssid)   { $s.Ssid   } else { '-' }
    $lblPassVal.Text  = if ($s.Pass)   { $s.Pass   } else { '-' }

    # Maintain column widths (only default auto-fit if <= 0)
    $w0 = $listView.Columns[0].Width
    $w1 = $listView.Columns[1].Width
    $w2 = $listView.Columns[2].Width
    $w3 = $listView.Columns[3].Width
    $listView.Items.Clear()
    if ($cnt -eq 0) {
        $item = New-Object System.Windows.Forms.ListViewItem 'No devices connected'
        $item.ForeColor = $C.Sub
        $null = $listView.Items.Add($item)
    } else {
        foreach ($c in $s.Clients) {
            $tokens = $c.Host -split '\s+'
            $hn = $tokens[0]
            $ip = if ($tokens.Count -ge 2) { $tokens[-1] } else { '' }
            $item = New-Object System.Windows.Forms.ListViewItem $hn
            $null = $item.SubItems.Add($ip)
            $null = $item.SubItems.Add($c.Mac)
            $null = $item.SubItems.Add($c.Duration)
            $null = $listView.Items.Add($item)
        }
    }
    if ($w0 -gt 0) { $listView.Columns[0].Width=$w0 } else { $listView.Columns[0].Width=-2 }
    if ($w1 -gt 0) { $listView.Columns[1].Width=$w1 } else { $listView.Columns[1].Width=-2 }
    if ($w2 -gt 0) { $listView.Columns[2].Width=$w2 } else { $listView.Columns[2].Width=-2 }
    if ($w3 -gt 0) { $listView.Columns[3].Width=$w3 } else { $listView.Columns[3].Width=-2 }
}

# ---------------------------------------------------------------------------
# Full refresh & WAN Auto-Recovery
# ---------------------------------------------------------------------------
function Do-Refresh {
    if ($script:isSleeping) { return }

    $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    $isWanUp = ($null -ne $profile)

    # If WAN is UP and auto-resume is wanted, check if hotspot needs auto-starting
    if ($isWanUp -and $script:autoResumeWanted -and -not $script:isBusy) {
        $curState = Get-HotspotStatus
        if ($curState.State -ne 'On' -and $curState.State -ne 'InTransition') {
            # Auto-start hotspot on WAN UP
            $script:lastWanProfile = $profile.ProfileName
            Do-HotspotAction 'Start' $true  # silent auto-start
            return
        }
        $script:lastWanProfile = $profile.ProfileName
    } elseif (-not $isWanUp) {
        $script:lastWanProfile = $null
    }

    $script:lastStatus = Get-HotspotStatus
    Update-Tray
    if ($form.Visible) { Update-FormUI }
}

# ---------------------------------------------------------------------------
# Hotspot action
# ---------------------------------------------------------------------------
function Do-HotspotAction ([string]$Action, [bool]$IsAuto=$false) {
    if ($script:isBusy -or $script:isSleeping) { return }
    $script:isBusy     = $true
    $btnToggle.Enabled = $false
    $busy = if ($Action -eq 'Start') { 'Starting...' } else { 'Stopping...' }
    if ($form.Visible) {
        $lblState.Text = $busy; $lblState.ForeColor = $C.Yellow; $lblDot.ForeColor = $C.Yellow
        $btnToggle.Text = $busy; $btnToggle.BackColor = $C.Yellow
    }
    $script:notifyIcon.Icon = New-TrayIcon 'Busy'
    $script:notifyIcon.Text = "Hotspot: $busy"
    [System.Windows.Forms.Application]::DoEvents()
    
    $err = Invoke-HotspotAction $Action
    if ($null -ne $err -and -not $IsAuto) {
        [System.Windows.Forms.MessageBox]::Show($err, 'Hotspot Manager Error', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }

    # Update user desired state
    if ($Action -eq 'Start') {
        $script:autoResumeWanted = $true
    } elseif ($Action -eq 'Stop' -and -not $IsAuto) {
        $script:autoResumeWanted = $false
    }
    
    $script:lastStatus = Get-HotspotStatus
    Update-Tray
    if ($form.Visible) { Update-FormUI }

    $btnToggle.Enabled = $true
    $script:isBusy     = $false
}

# ---------------------------------------------------------------------------
# Button events
# ---------------------------------------------------------------------------
$btnToggle.Add_Click({
    if ($script:isBusy) { return }
    $curState = (Get-HotspotStatus).State
    if ($curState -eq 'On') {
        $script:autoResumeWanted = $false
        Do-HotspotAction 'Stop'
    } elseif ($script:autoResumeWanted -and ($null -eq [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile())) {
        # User clicked Stop Auto-Resume while waiting for WAN
        $script:autoResumeWanted = $false
        $script:lastStatus = Get-HotspotStatus
        Update-Tray
        if ($form.Visible) { Update-FormUI }
    } else {
        $script:autoResumeWanted = $true
        Do-HotspotAction 'Start'
    }
})
$btnRefresh.Add_Click({ Do-Refresh })

$form.Add_FormClosing({
    param($s,$e)
    Save-Config
    $e.Cancel=$true
    $form.Hide()
})
$form.Add_ResizeEnd({ Save-Config })
$listView.Add_ColumnWidthChanged({ Save-Config })
$form.Add_VisibleChanged({ if ($form.Visible) { Update-FormUI } })

# ---------------------------------------------------------------------------
# Power Management (Sleep / Suspend Detection)
# ---------------------------------------------------------------------------
$script:powerHandler = [Microsoft.Win32.PowerModeChangedEventHandler]{
    param($sender, $e)
    try {
        if ($e.Mode -eq [Microsoft.Win32.PowerModes]::Suspend) {
            # System is going to sleep: stop hotspot immediately to allow sleep
            $script:isSleeping = $true
            $cur = Get-HotspotStatus
            if ($cur.State -eq 'On') {
                $script:wasRunningBeforeSleep = $true
                Invoke-HotspotAction 'Stop'
            } else {
                $script:wasRunningBeforeSleep = $false
            }
        } elseif ($e.Mode -eq [Microsoft.Win32.PowerModes]::Resume) {
            # System waking up: restore auto-resume flag
            $script:isSleeping = $false
            if ($script:wasRunningBeforeSleep) {
                $script:autoResumeWanted = $true
                $script:wasRunningBeforeSleep = $false
            }
            Do-Refresh
        }
    } catch {}
}
[Microsoft.Win32.SystemEvents]::add_PowerModeChanged($script:powerHandler)

# ---------------------------------------------------------------------------
# Auto-refresh timer (4s)
# ---------------------------------------------------------------------------
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 4000
$timer.Add_Tick({ if (-not $script:isBusy) { Do-Refresh } })
$timer.Start()

# ---------------------------------------------------------------------------
# NotifyIcon + context menu
# ---------------------------------------------------------------------------
$script:notifyIcon        = New-Object System.Windows.Forms.NotifyIcon
$script:notifyIcon.Icon   = New-TrayIcon 'Off'
$script:notifyIcon.Text   = 'Hotspot Manager'
$script:notifyIcon.Visible= $true

$ctxMenu        = New-Object System.Windows.Forms.ContextMenuStrip
$miOpen         = $ctxMenu.Items.Add('Open Panel')
$ctxMenu.Items.Add('-') | Out-Null
$script:miStart = $ctxMenu.Items.Add('Start Hotspot')
$script:miStop  = $ctxMenu.Items.Add('Stop Hotspot')
$ctxMenu.Items.Add('-') | Out-Null
$miExit         = $ctxMenu.Items.Add('Exit')
$miOpen.Font    = $fntMenuBold

function Show-Form {
    $form.Show(); $form.WindowState=[System.Windows.Forms.FormWindowState]::Normal; $form.Activate()
}

$miOpen.Add_Click({         Show-Form })
$script:miStart.Add_Click({ $script:autoResumeWanted = $true;  Do-HotspotAction 'Start' })
$script:miStop.Add_Click({  $script:autoResumeWanted = $false; Do-HotspotAction 'Stop'  })
$miExit.Add_Click({
    if ($null -ne $script:powerHandler) {
        [Microsoft.Win32.SystemEvents]::remove_PowerModeChanged($script:powerHandler)
    }
    Save-Config
    $timer.Stop()
    $script:notifyIcon.Visible=$false; $script:notifyIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$script:notifyIcon.ContextMenuStrip = $ctxMenu
$script:notifyIcon.Add_DoubleClick({ Show-Form })

# ---------------------------------------------------------------------------
# Start
# ---------------------------------------------------------------------------
Do-Refresh
[System.Windows.Forms.Application]::Run()
