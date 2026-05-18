<#
.SYNOPSIS
  Build a NoCloud seed ISO containing user-data + meta-data files, with
  volume label CIDATA (required by cloud-init's NoCloud datasource).

.PARAMETER OutFile
  Path the ISO will be written to.

.PARAMETER UserDataContent
  Raw cloud-init user-data string.

.PARAMETER MetaDataContent
  Raw cloud-init meta-data string.

.NOTES
  Uses IMAPI2FS.MsftFileSystemImage (built into Windows Server 2016+;
  no ADK / no oscdimg needed).

.EXAMPLE
  Build-NoCloudIso -OutFile C:\tmp\seed.iso -UserDataContent "#cloud-config..." -MetaDataContent "instance-id: pub-1"

  # Verify volume label after building:
  $img = Mount-DiskImage -ImagePath C:\tmp\seed.iso -PassThru
  (Get-Volume -DiskImage $img).FileSystemLabel  # -> CIDATA
  Dismount-DiskImage -ImagePath C:\tmp\seed.iso
#>
function Build-NoCloudIso {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string] $OutFile,
    [Parameter(Mandatory)] [string] $UserDataContent,
    [Parameter(Mandatory)] [string] $MetaDataContent
  )

  $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ("nocloud-" + [Guid]::NewGuid())
  New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

  try {
    # Cloud-init NoCloud datasource requires LF line endings.
    $userDataPath = Join-Path $stagingDir "user-data"
    $metaDataPath = Join-Path $stagingDir "meta-data"
    [System.IO.File]::WriteAllText($userDataPath, ($UserDataContent -replace "`r`n","`n"))
    [System.IO.File]::WriteAllText($metaDataPath, ($MetaDataContent -replace "`r`n","`n"))

    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 7  # ISO9660 + Joliet + UDF
    $fsi.VolumeName          = 'CIDATA'

    $root = $fsi.Root
    $root.AddTree($stagingDir, $false)

    $result = $fsi.CreateResultImage()
    $stream = $result.ImageStream

    $outDir = Split-Path -Parent $OutFile
    if (-not (Test-Path $outDir)) {
      New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    # Persist COM IStream to disk.
    $bytes      = New-Object byte[] $result.BlockSize
    $fileStream = [System.IO.File]::Create($OutFile)
    try {
      $intRead = 0
      do {
        $stream.Read([ref] $bytes, $result.BlockSize, [ref] $intRead) | Out-Null
        $fileStream.Write($bytes, 0, $intRead)
      } while ($intRead -eq $result.BlockSize)
    } finally {
      $fileStream.Close()
    }
  } finally {
    Remove-Item -Recurse -Force $stagingDir -ErrorAction SilentlyContinue
  }
}
