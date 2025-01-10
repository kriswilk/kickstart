if (!(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Output "You need elevated privileges to run this script."
    exit
}

$standardPackages = @(
    # core
    "7zip.7zip",
    "Git.Git",
    "AutoHotkey.AutoHotkey",
    "Microsoft.OneDrive",
    "Bitwarden.Bitwarden",

    # browser
    "Google.Chrome",

    # font
    "SourceFoundry.HackFonts",

    # console
    "Microsoft.PowerShell",

    # suite
    "Microsoft.Office",
    "Adobe.CreativeCloud",

    # utility
    "Microsoft.PowerToys",
    "Microsoft.Sysinternals",
    "SumatraPDF.SumatraPDF",
    "ScooterSoftware.BeyondCompare.5", #....... apply license
    "FineprintSoftware.FinePrint", #........... apply license, icon(s) in wrong start menu
    "den4b.ReNamer", #......................... apply license
"")

$optionalPackages = @(
    # utility
    "REALiX.HWiNFO",

    # audio
    "Audacity.Audacity",

    # video
    "VideoLAN.VLC",
    "HandBrake.HandBrake",
    "MoritzBunkus.MKVToolNix",
    "Gyan.FFmpeg",

    # photo/illustration
    "GIMP.GIMP",
    "Inkscape.Inkscape", #..................... icon(s) in wrong start menu
    "KDE.Krita",

    # print/scan
    "Cyanfish.NAPS2",

    # 3d / cad
    "BlenderFoundation.Blender", #............. icon(s) in wrong start menu
    "FreeCAD.FreeCAD",
    "KiCad.KiCad",
    "Prusa3D.PrusaSlicer",

    # text
    # "calibre.calibre",
    "JohnMacFarlane.Pandoc",

    # programming
    "Microsoft.VisualStudioCode",
    "WerWolv.ImHex",

    # networking
    "Famatech.AdvancedIPScanner",
    "tailscale.tailscale",
    "WiresharkFoundation.Wireshark",
    "WinSCP.WinSCP",

    # storage
    "Rclone.Rclone",
    "Rufus.Rufus",
    "PowerSoftware.AnyBurn",
    "AntibodySoftware.WizTree",
    "CrystalDewWorld.CrystalDiskInfo",
    "CrystalDewWorld.CrystalDiskMark",

    # gaming
    "Valve.Steam",
    "Microsoft.OpenJDK.21" #................... for minecraft / prism launcher
"")

# STANDARD PACKAGES
if ((Read-Host "Install Standard Packages? (y/n)") -eq "y")
{
    $standardPackages | ForEach-Object { if ($_) { winget install --scope machine -e --id $_ }}
    
    # no machine scope
    winget install -e --id "Microsoft.WindowsTerminal"
}

# OPTIONAL PACKAGES
if ((Read-Host "Install Optional Packages? (y/n)") -eq "y")
{
    $optionalPackages | ForEach-Object { if ($_) { winget install --scope machine -e --id $_ }}
    
    # no machine scope
    winget install -e --id "PrismLauncher.PrismLauncher"
}

# SERVARR PACKAGES
if ((Read-Host "Install Servarr Packages? (y/n)") -eq "y")
{
    winget install -e --id "Plex.PlexMediaServer"
    winget install -e --id "SABnzbdTeam.SABnzbd"
    winget install -e --id "qBittorrent.qBittorrent"
    winget install -e --id "AppWork.JDownloader" # software installs to Program Files but shortcuts to user!?
    winget install -e --id "TeamSonarr.Sonarr" --override "/silent /mergetasks=startupshortcut"
    winget install -e --id "TeamRadarr.Radarr" --override "/silent /mergetasks=startupshortcut"
    winget install -e --id "TeamLidarr.Lidarr" --override "/silent /mergetasks=startupshortcut"
    winget install -e --id "TeamReadarr.Readarr" --override "/silent /mergetasks=startupshortcut"
    winget install -e --id "TeamProwlarr.Prowlarr" --override "/silent /mergetasks=startupshortcut"

    # pin self-updating / problematically-versioned items
    winget pin add -e --id "Plex.PlexMediaServer"
    winget pin add -e --id "TeamSonarr.Sonarr"
    winget pin add -e --id "TeamRadarr.Radarr"
    winget pin add -e --id "TeamLidarr.Lidarr"
    winget pin add -e --id "TeamReadarr.Readarr"
    winget pin add -e --id "TeamProwlarr.Prowlarr"
}
