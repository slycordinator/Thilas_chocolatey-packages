﻿param([switch] $Force, [switch] $SkipPrerelease)

function getLatest {
  $fileType       = 'exe'
  $silentArgs     = '/S'
  $validExitCodes = '0'

  $uninstallSoftwareName   = 'Kodi*'
  $uninstallFileType       = 'exe'
  $uninstallSilentArgs     = '/S'
  $uninstallValidExitCodes = '0'

  if ($SkipPrerelease) {
    $releasesUrl = 'https://api.github.com/repos/xbmc/xbmc/releases/latest'
  } else {
    $releasesUrl = 'https://api.github.com/repos/xbmc/xbmc/releases'
  }
  $releases = (Invoke-WebRequest -Uri $releasesUrl -UseBasicParsing).Content | ConvertFrom-Json
  $releases = $releases | Select-Object -First 1
  $tag = $releases.tag_name
  $version = $tag -Match '^(?<version>\d+(?:\.\d+)*)(?<prerelease>.+)?-'
  if (!$version) { throw 'Version not found.' }
  $version = $Matches['version']
  if ($Matches['prerelease']) { $version = "$version-$($Matches['prerelease'])" }

  $downloadsUrl = 'https://kodi.tv/download/849'
  $downloads = Invoke-WebRequest -Uri $downloadsUrl -UseBasicParsing
  $urls = @($downloads.Links | ? href -Like "*win32*$tag*.$fileType")
  if ($urls.Length -ne 1) { throw 'Url (x86) not found.' }
  $url32 = $urls[0].href
  $urls = @($downloads.Links | ? href -Like "*win64*$tag*.$fileType")
  if ($urls.Length -gt 0) {
    if ($urls.Length -ne 1) { throw 'Url (x64) not found.' }
    $url64 = $urls[0].href
  } else {
    $url64 = $url32
  }

  return @{
    Version                 = $version
    FileType                = $fileType
    Url32                   = $url32
    Url64                   = $url64
    SilentArgs              = $silentArgs
    ValidExitCodes          = $validExitCodes
    UninstallSoftwareName   = $uninstallSoftwareName
    UninstallFileType       = $uninstallFileType
    UninstallSilentArgs     = $uninstallSilentArgs
    UninstallValidExitCodes = $uninstallValidExitCodes
  }
}

function searchReplace {
  @{
    'tools\chocolateyInstall.ps1' = @{
      "^(\s*packageName\s*=\s*)'.*'$"       = "`$1'$($Latest.PackageName)'"
      "^(\s*fileType\s*=\s*)'.*'$"          = "`$1'$($Latest.FileType)'"
      "^(\s*url\s*=\s*)'.*'$"               = "`$1'$($Latest.Url32)'"
      "^(\s*url64bit\s*=\s*)'.*'$"          = "`$1'$($Latest.Url64)'"
      "^(\s*silentArgs\s*=\s*)'.*'$"        = "`$1'$($Latest.SilentArgs)'"
      "^(\s*checksum\s*=\s*)'.*'$"          = "`$1'$($Latest.Checksum32)'"
      "^(\s*checksumType\s*=\s*)'.*'$"      = "`$1'$($Latest.ChecksumType32)'"
      "^(\s*checksum64\s*=\s*)'.*'$"        = "`$1'$($Latest.Checksum64)'"
      "^(\s*checksumType64\s*=\s*)'.*'$"    = "`$1'$($Latest.ChecksumType64)'"
      "^(\s*validExitCodes\s*=\s*)@\(.*\)$" = "`$1@($($Latest.ValidExitCodes))"
    }
    'tools\chocolateyUninstall.ps1' = @{
      "^([$]packageName\s*=\s*)'.*'$"       = "`$1'$($Latest.PackageName)'"
      "^([$]softwareName\s*=\s*)'.*'$"      = "`$1'$($Latest.UninstallSoftwareName)'"
      "^([$]fileType\s*=\s*)'.*'$"          = "`$1'$($Latest.UninstallFileType)'"
      "^([$]silentArgs\s*=\s*)'.*'$"        = "`$1'$($Latest.UninstallSilentArgs)'"
      "^([$]validExitCodes\s*=\s*)@\(.*\)$" = "`$1@($($Latest.UninstallValidExitCodes))"
    }
  }
}

. '..\Update-Package.ps1' -AllowLowerVersion -ChecksumFor all -Force:$Force