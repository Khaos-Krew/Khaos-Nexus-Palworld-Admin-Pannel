param([switch]$PreviewOnly)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, "KhaosAdminDeckUI-v020", [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.MessageBox]::Show("Khaos Admin Deck is already open.", "Khaos Admin Deck", "OK", "Information") | Out-Null
    exit 0
}

$UiDir = $PSScriptRoot
$ModRoot = Split-Path -Parent $UiDir
$IpcDir = Join-Path $ModRoot "ipc"
$RequestPath = Join-Path $IpcDir "request.kad"
$RequestTempPath = Join-Path $IpcDir "request.kad.tmp"
$StatusPath = Join-Path $IpcDir "status.kad"
$ActivityPath = Join-Path $IpcDir "activity.log"
New-Item -ItemType Directory -Path $IpcDir -Force | Out-Null

function ConvertTo-HexString {
    param([AllowEmptyString()][string]$Value)
    if ($null -eq $Value) { $Value = "" }
    return -join ([System.Text.Encoding]::UTF8.GetBytes($Value) | ForEach-Object { $_.ToString("X2") })
}

function ConvertFrom-HexString {
    param([AllowEmptyString()][string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { return "" }
    if (($Value.Length % 2) -ne 0 -or $Value -notmatch '^[0-9A-Fa-f]+$') { return "" }

    $bytes = New-Object byte[] ($Value.Length / 2)
    for ($index = 0; $index -lt $bytes.Length; $index++) {
        $bytes[$index] = [Convert]::ToByte($Value.Substring($index * 2, 2), 16)
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Read-KeyValueFile {
    param([string]$Path)
    $result = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $result }

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $position = $line.IndexOf("=")
        if ($position -gt 0) {
            $result[$line.Substring(0, $position)] = $line.Substring($position + 1)
        }
    }
    return $result
}

function Send-DeckRequest {
    param(
        [Parameter(Mandatory)][string]$Action,
        [string[]]$Arguments = @(),
        [switch]$Confirmed
    )

    if (Test-Path -LiteralPath $RequestPath) {
        $age = (Get-Date) - (Get-Item -LiteralPath $RequestPath).LastWriteTime
        if ($age.TotalSeconds -lt 4) {
            [System.Windows.MessageBox]::Show(
                "The previous request is still waiting for the client mod. Make sure Palworld and UE4SS are running.",
                "Request pending", "OK", "Warning"
            ) | Out-Null
            return
        }
        Remove-Item -LiteralPath $RequestPath -Force -ErrorAction SilentlyContinue
    }

    $requestId = [Guid]::NewGuid().ToString("N")
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("version=1")
    $lines.Add("id=$requestId")
    $lines.Add("action=$Action")
    $lines.Add("confirmed=" + ($(if ($Confirmed) { "1" } else { "0" })))

    for ($index = 0; $index -lt $Arguments.Count; $index++) {
        $lines.Add("arg$($index + 1)=" + (ConvertTo-HexString $Arguments[$index]))
    }

    [System.IO.File]::WriteAllLines($RequestTempPath, $lines, [System.Text.Encoding]::UTF8)
    Move-Item -LiteralPath $RequestTempPath -Destination $RequestPath -Force
}

function Confirm-DangerousAction {
    param([string]$Title, [string]$Message)
    return [System.Windows.MessageBox]::Show($Message, $Title, "YesNo", "Warning") -eq "Yes"
}

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Khaos Admin Deck"
        Width="1060" Height="780" MinWidth="940" MinHeight="700"
        WindowStartupLocation="CenterScreen" Topmost="True"
        Background="#0D0D10" Foreground="#F3F3F5" FontFamily="Segoe UI">
    <Window.Resources>
        <SolidColorBrush x:Key="PanelBrush" Color="#17171C"/>
        <SolidColorBrush x:Key="AccentBrush" Color="#D32236"/>
        <SolidColorBrush x:Key="AccentHoverBrush" Color="#F03A4D"/>
        <SolidColorBrush x:Key="BorderBrush" Color="#393941"/>
        <Style TargetType="Button">
            <Setter Property="Background" Value="{StaticResource AccentBrush}"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="14,9"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="MinHeight" Value="38"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{StaticResource AccentHoverBrush}"/>
                </Trigger>
                <Trigger Property="IsEnabled" Value="False">
                    <Setter Property="Opacity" Value="0.45"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#101014"/>
            <Setter Property="Foreground" Value="#F5F5F7"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9"/>
            <Setter Property="Margin" Value="4"/>
            <Setter Property="CaretBrush" Value="White"/>
        </Style>
        <Style TargetType="PasswordBox">
            <Setter Property="Background" Value="#101014"/>
            <Setter Property="Foreground" Value="#F5F5F7"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="9"/>
            <Setter Property="Margin" Value="4"/>
        </Style>
        <Style TargetType="GroupBox">
            <Setter Property="Foreground" Value="#F2F2F4"/>
            <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
            <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
            <Setter Property="Margin" Value="7"/>
            <Setter Property="Padding" Value="10"/>
        </Style>
        <Style TargetType="Label"><Setter Property="Foreground" Value="#D7D7DC"/></Style>
    </Window.Resources>

    <Grid Margin="14">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" Background="#151519" BorderBrush="#D32236" BorderThickness="0,0,0,3" Padding="18">
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <StackPanel>
                    <TextBlock Text="KHAOS ADMIN DECK" FontSize="28" FontWeight="Bold"/>
                    <TextBlock Text="Palworld client administration overlay • v0.2.0 preview" Foreground="#A7A7AE" Margin="0,4,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border x:Name="ConnectionBadge" Background="#442026" CornerRadius="12" Padding="12,6" Margin="4">
                        <TextBlock x:Name="ConnectionText" Text="CLIENT OFFLINE" FontWeight="Bold"/>
                    </Border>
                    <Border x:Name="AdminBadge" Background="#3A2F18" CornerRadius="12" Padding="12,6" Margin="4">
                        <TextBlock x:Name="AdminText" Text="NOT AUTHENTICATED" FontWeight="Bold"/>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <Border Grid.Row="1" Background="{StaticResource PanelBrush}" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1" Padding="12" Margin="0,12,0,6">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/><ColumnDefinition Width="260"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Label Grid.Column="0" Content="Admin password:" VerticalAlignment="Center"/>
                <PasswordBox Grid.Column="1" x:Name="PasswordInput"/>
                <Button Grid.Column="2" x:Name="AuthenticateButton" Content="Authenticate"/>
                <StackPanel Grid.Column="3" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                    <TextBlock Text="Player: " Foreground="#91919A"/>
                    <TextBlock x:Name="PlayerNameText" Text="Not connected" FontWeight="SemiBold"/>
                </StackPanel>
            </Grid>
        </Border>

        <Grid Grid.Row="2">
            <Grid.ColumnDefinitions><ColumnDefinition Width="1.08*"/><ColumnDefinition Width="0.92*"/></Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0">
                <GroupBox Header="Quick Actions">
                    <UniformGrid Columns="4">
                        <Button x:Name="SaveButton" Content="Save World"/>
                        <Button x:Name="PlayersButton" Content="Show Players"/>
                        <Button x:Name="InfoButton" Content="Server Info"/>
                        <Button x:Name="SpectateButton" Content="Spectate"/>
                    </UniformGrid>
                </GroupBox>

                <GroupBox Header="Broadcast">
                    <Grid>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                        <TextBox Grid.Column="0" x:Name="BroadcastInput" Height="42" ToolTip="Message sent to all players"/>
                        <Button Grid.Column="1" x:Name="BroadcastButton" Content="Send Broadcast"/>
                    </Grid>
                </GroupBox>

                <GroupBox Header="Player Actions">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                        <Label Grid.Row="0" Grid.Column="0" Content="Player ID:" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" x:Name="PlayerIdInput" ToolTip="Use the exact ID shown by Show Players"/>
                        <UniformGrid Grid.Row="1" Grid.ColumnSpan="2" Columns="5">
                            <Button x:Name="KickButton" Content="Kick"/>
                            <Button x:Name="BanButton" Content="Ban"/>
                            <Button x:Name="UnbanButton" Content="Unban"/>
                            <Button x:Name="TeleportButton" Content="Go To"/>
                            <Button x:Name="BringButton" Content="Bring"/>
                        </UniformGrid>
                    </Grid>
                </GroupBox>

                <GroupBox Header="Server Shutdown">
                    <Grid>
                        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="95"/><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Label Grid.Row="0" Grid.Column="0" Content="Seconds:" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" x:Name="ShutdownSecondsInput" Text="600"/>
                        <Button Grid.Row="0" Grid.Column="2" x:Name="ShutdownButton" Content="Schedule"/>
                        <Button Grid.Row="0" Grid.Column="3" x:Name="ExitButton" Content="Force Exit" Background="#7F1724"/>
                        <Label Grid.Row="1" Grid.Column="0" Content="Message:" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="3" x:Name="ShutdownMessageInput" Text="Scheduled maintenance"/>
                    </Grid>
                </GroupBox>
            </StackPanel>

            <GroupBox Grid.Column="1" Header="Activity">
                <Grid>
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <Border Grid.Row="0" Background="#101014" BorderBrush="#393941" BorderThickness="1" Padding="10" Margin="4">
                        <StackPanel>
                            <TextBlock Text="Last result" Foreground="#8E8E97" FontSize="12"/>
                            <TextBlock x:Name="LastResultText" Text="Waiting for the client mod..." TextWrapping="Wrap" Margin="0,4,0,0"/>
                        </StackPanel>
                    </Border>
                    <TextBox Grid.Row="1" x:Name="ActivityText" IsReadOnly="True" FontFamily="Consolas" FontSize="12" TextWrapping="NoWrap" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"/>
                    <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
                        <Button x:Name="RefreshButton" Content="Refresh"/>
                        <Button x:Name="OpenFolderButton" Content="Open Mod Folder" Background="#34343C"/>
                        <Button x:Name="CloseButton" Content="Close" Background="#34343C"/>
                    </StackPanel>
                </Grid>
            </GroupBox>
        </Grid>

        <Border Grid.Row="3" Background="#121216" Padding="10" Margin="0,8,0,0">
            <TextBlock x:Name="FooterText" Text="F9 opens this panel. Commands still require the server's real AdminPassword." Foreground="#9C9CA5"/>
        </Border>
    </Grid>
</Window>
'@

[xml]$xamlXml = $xaml
$reader = New-Object System.Xml.XmlNodeReader $xamlXml
$window = [Windows.Markup.XamlReader]::Load($reader)

function Get-Control([string]$Name) { return $window.FindName($Name) }

$ConnectionBadge = Get-Control "ConnectionBadge"
$ConnectionText = Get-Control "ConnectionText"
$AdminBadge = Get-Control "AdminBadge"
$AdminText = Get-Control "AdminText"
$PlayerNameText = Get-Control "PlayerNameText"
$PasswordInput = Get-Control "PasswordInput"
$AuthenticateButton = Get-Control "AuthenticateButton"
$SaveButton = Get-Control "SaveButton"
$PlayersButton = Get-Control "PlayersButton"
$InfoButton = Get-Control "InfoButton"
$SpectateButton = Get-Control "SpectateButton"
$BroadcastInput = Get-Control "BroadcastInput"
$BroadcastButton = Get-Control "BroadcastButton"
$PlayerIdInput = Get-Control "PlayerIdInput"
$KickButton = Get-Control "KickButton"
$BanButton = Get-Control "BanButton"
$UnbanButton = Get-Control "UnbanButton"
$TeleportButton = Get-Control "TeleportButton"
$BringButton = Get-Control "BringButton"
$ShutdownSecondsInput = Get-Control "ShutdownSecondsInput"
$ShutdownMessageInput = Get-Control "ShutdownMessageInput"
$ShutdownButton = Get-Control "ShutdownButton"
$ExitButton = Get-Control "ExitButton"
$ActivityText = Get-Control "ActivityText"
$LastResultText = Get-Control "LastResultText"
$RefreshButton = Get-Control "RefreshButton"
$OpenFolderButton = Get-Control "OpenFolderButton"
$CloseButton = Get-Control "CloseButton"
$FooterText = Get-Control "FooterText"

$script:lastActivityLength = -1

function Update-DeckStatus {
    $status = Read-KeyValueFile $StatusPath
    $heartbeat = 0L
    [void][long]::TryParse(($status["heartbeat"] | ForEach-Object { $_ }), [ref]$heartbeat)
    $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $alive = ($heartbeat -gt 0 -and ($nowEpoch - $heartbeat) -le 6)
    $connected = ($status["connected"] -eq "1" -and $alive)
    $admin = ($status["admin"] -eq "1" -and $connected)

    if ($connected) {
        $ConnectionText.Text = "CLIENT CONNECTED"
        $ConnectionBadge.Background = "#173E2B"
    } elseif ($alive) {
        $ConnectionText.Text = "MOD LOADED"
        $ConnectionBadge.Background = "#3A2F18"
    } else {
        $ConnectionText.Text = "CLIENT OFFLINE"
        $ConnectionBadge.Background = "#442026"
    }

    if ($admin) {
        $AdminText.Text = "ADMIN ACTIVE"
        $AdminBadge.Background = "#173E2B"
    } else {
        $AdminText.Text = "NOT AUTHENTICATED"
        $AdminBadge.Background = "#3A2F18"
    }

    $player = ConvertFrom-HexString ($status["player"])
    $PlayerNameText.Text = $(if ([string]::IsNullOrWhiteSpace($player)) { "Not connected" } else { $player })

    $lastResult = ConvertFrom-HexString ($status["lastResult"])
    if (-not [string]::IsNullOrWhiteSpace($lastResult)) { $LastResultText.Text = $lastResult }

    foreach ($control in @($SaveButton, $PlayersButton, $InfoButton, $SpectateButton, $BroadcastButton, $KickButton, $BanButton, $UnbanButton, $TeleportButton, $BringButton, $ShutdownButton, $ExitButton)) {
        $control.IsEnabled = ($admin -or $PreviewOnly)
    }

    if (Test-Path -LiteralPath $ActivityPath) {
        $length = (Get-Item -LiteralPath $ActivityPath).Length
        if ($length -ne $script:lastActivityLength) {
            $lines = Get-Content -LiteralPath $ActivityPath -Tail 150 -ErrorAction SilentlyContinue
            $ActivityText.Text = ($lines -join [Environment]::NewLine)
            $ActivityText.ScrollToEnd()
            $script:lastActivityLength = $length
        }
    }

    if ($PreviewOnly) {
        $FooterText.Text = "UI preview mode: buttons render normally but the Palworld client mod is not required."
    }
}

$AuthenticateButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($PasswordInput.Password)) {
        [System.Windows.MessageBox]::Show("Enter the server AdminPassword.", "Authentication", "OK", "Warning") | Out-Null
        return
    }
    Send-DeckRequest -Action "auth" -Arguments @($PasswordInput.Password)
    $PasswordInput.Clear()
})

$SaveButton.Add_Click({ Send-DeckRequest -Action "save" })
$PlayersButton.Add_Click({ Send-DeckRequest -Action "players" })
$InfoButton.Add_Click({ Send-DeckRequest -Action "info" })
$SpectateButton.Add_Click({ Send-DeckRequest -Action "spectate" })

$BroadcastButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($BroadcastInput.Text)) { return }
    Send-DeckRequest -Action "broadcast" -Arguments @($BroadcastInput.Text)
    $BroadcastInput.Clear()
})

function Get-PlayerIdOrWarn {
    $identifier = $PlayerIdInput.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($identifier) -or $identifier.Contains(" ")) {
        [System.Windows.MessageBox]::Show("Enter the exact player identifier shown by Show Players.", "Player ID required", "OK", "Warning") | Out-Null
        return $null
    }
    return $identifier
}

$KickButton.Add_Click({
    $id = Get-PlayerIdOrWarn
    if ($id -and (Confirm-DangerousAction "Kick player" "Kick player $id from the server?")) {
        Send-DeckRequest -Action "kick" -Arguments @($id) -Confirmed
    }
})

$BanButton.Add_Click({
    $id = Get-PlayerIdOrWarn
    if ($id -and (Confirm-DangerousAction "Ban player" "Ban player $id?")) {
        Send-DeckRequest -Action "ban" -Arguments @($id) -Confirmed
    }
})

$UnbanButton.Add_Click({ $id = Get-PlayerIdOrWarn; if ($id) { Send-DeckRequest -Action "unban" -Arguments @($id) } })
$TeleportButton.Add_Click({ $id = Get-PlayerIdOrWarn; if ($id) { Send-DeckRequest -Action "teleport" -Arguments @($id) } })
$BringButton.Add_Click({ $id = Get-PlayerIdOrWarn; if ($id) { Send-DeckRequest -Action "bring" -Arguments @($id) } })

$ShutdownButton.Add_Click({
    $seconds = 0
    if (-not [int]::TryParse($ShutdownSecondsInput.Text, [ref]$seconds) -or $seconds -lt 0 -or $seconds -gt 86400) {
        [System.Windows.MessageBox]::Show("Shutdown seconds must be between 0 and 86400.", "Invalid shutdown time", "OK", "Warning") | Out-Null
        return
    }
    if (Confirm-DangerousAction "Schedule shutdown" "Shut the server down in $seconds seconds?") {
        Send-DeckRequest -Action "shutdown" -Arguments @("$seconds", $ShutdownMessageInput.Text) -Confirmed
    }
})

$ExitButton.Add_Click({
    if (Confirm-DangerousAction "Force server exit" "Immediately stop the Palworld server without a countdown?") {
        Send-DeckRequest -Action "exit" -Confirmed
    }
})

$RefreshButton.Add_Click({ Send-DeckRequest -Action "status"; Update-DeckStatus })
$OpenFolderButton.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$ModRoot`"" })
$CloseButton.Add_Click({ $window.Close() })

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Update-DeckStatus })
$timer.Start()

$window.Add_Closed({
    $timer.Stop()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
})

Update-DeckStatus
[void]$window.ShowDialog()
