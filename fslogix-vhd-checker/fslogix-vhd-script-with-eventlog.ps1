<# added Profile file generation
 getting file properties to compare to mounted volume properties
 5a - added Size on Disk and percentage empty on disk
 need to read redirections (and mark all possible redirections to note of they are active or not.
 then look for problematic files and report. Duplicate OST, NST, report size, OST, NST, EDB relative to OST,
 6 - add ability to look for duplicate OST and large .edb files.
#> 

$freeSpaceWarningThreshold = 1024
$freeSpaceErrorThreshold = 256

function Folder-ExistOrCreate 
{
Param($strLocation)
if( -Not (Test-Path -Path $strLocation -PathType Container ) )
  {
  New-Item -ItemType directory -Path $strLocation
  }
}
function File-ExistOrCreate
{
Param($strLocation)
if( -Not (Test-Path -Path $strLocation -PathType Leaf ) )
  {
  New-Item -ItemType file -Path $strLocation
  }
}

function Get-ADUserName
{
Param($strSID)
$objSID = New-Object System.Security.Principal.SecurityIdentifier($strSID)
$objUser = $objSID.Translate([System.Security.Principal.NTAccount])
$objUser.Value
}

$objVolumes = Get-Volume

$objRegODFC = Get-ItemProperty -Path hklm:\software\policies\fslogix\odfc
$objRegProfile = Get-ItemProperty -Path hklm:\software\fslogix\profiles

$objRegODFCSessions = gci -Path hklm:\software\policies\fslogix\odfc\sessions -Recurse
ForEach ($objSubKeysODFC in $objRegODFCSessions)
{
$objIndividualODFCKey = Get-ItemProperty -path "registry::$objSubKeysODFC"
if ($objIndividualODFCKey.RefCount -ge 1 -and $objIndividualODFCKey.VHDOpenedFilePath -ne "" )
  {
  $strUserName = ""
  $strUserName = Get-ADUserName -strSID (Split-Path -path $objSubKeysODFC -Leaf)
  ForEach ($objVolume in $objVolumes)
    {
    if ($objIndividualODFCKey.volume -eq $objVolume.path)
      {
      #Get-ItemProperty -Path $objIndividualODFCKey.VHDOpenedFilePath | Format-List -Property * # could be difference disk
      $objSizeOnDisk = Get-ItemProperty -Path $objIndividualODFCKey.VHDRootFilePath
      $strODFCParentPath = Split-Path -Path $objIndividualODFCKey.VHDOpenedFilePath -Parent
      $strODFC_VHD_Name = Split-Path -Path $objIndividualODFCKey.VHDOpenedFilePath -Leaf
      $strODFCBasePath = Split-Path -Path $strODFCParentPath -Parent
      $strODFCUserFolderName = Split-Path -Path $strODFCParentPath -Leaf
      $strODFCMGMTFolder = ("{0}\Mgmt" -f $strODFCBasePath)
      Folder-ExistOrCreate -strLocation $strODFCMGMTFolder
      $strODFC_Main_Name = ("{0}\Mgmt\{1}_ODFC_main.txt" -f $strODFCBasePath, $strODFCUserFolderName)
      $strOST_Main_Name = ("{0}\Mgmt\{1}_OST_main.txt" -f $strODFCBasePath, $strODFCUserFolderName)

      File-ExistOrCreate -strLocation $strODFC_Main_Name
      
      #write-host $objIndividualODFCKey.ODFCPath
      #get OST/NST routine
      $objOSTs = Get-childItem -Path $objIndividualODFCKey.ODFCPath -Recurse -Include *.OST
      $intOSTLoop = 1 
      foreach ($objOST in $objOSTs)
        {
        if ($intOSTLoop -eq 1)
          {
          set-content -Path $strOST_Main_Name  -Value ("{0}::{1}::{2}::{3}" -f $objOST.Name, $objOST.Length, $objOST.LastWriteTime, ( get-date -format o) )
          }
        else
          {
          add-content -Path $strOST_Main_Name  -Value ("{0}::{1}::{2}::{3}" -f $objOST.Name, $objOST.Length, $objOST.LastWriteTime, ( get-date -format o) )
          }
        #write-host $objOST.FullName
        $intOSTLoop = $intOSTLoop + 1
        }
      
      set-content -Path $strODFC_Main_Name -Value "VHD Name::$strODFC_VHD_Name"
      add-content -Path $strODFC_Main_Name -Value "Base Path::$strODFCBasePath"
      add-content -Path $strODFC_Main_Name -value ("VHD Folder::{0}" -f $strODFCUserFolderName )
      add-content -Path $strODFC_Main_Name -value ("User::{0}" -f $strUserName )
      add-content -Path $strODFC_Main_Name -value ("Computer::{0}" -f $Env:computername )
      add-content -Path $strODFC_Main_Name -value ("File System Label::{0}" -f $objVolume.FileSystemLabel)
      add-content -Path $strODFC_Main_Name -Value ("Space Remaining::{0}" -f $objVolume.SizeRemaining)
      add-content -Path $strODFC_Main_Name -value ("Volume Size::{0}" -f $objVolume.Size)
      $strPercentage = (($objVolume.SizeRemaining/$objVolume.Size) * 100).tostring("#.##")
      add-content -Path $strODFC_Main_Name -Value ("Percentage Space Remaining::{0}" -f $strPercentage)
      add-content -Path $strODFC_Main_Name -value ("Size on Disk::{0}" -f $objSizeOnDisk.Length)
      $strPercentage = ( 100 - ((($objVolume.Size - $objVolume.SizeRemaining)/$objSizeOnDisk.Length) * 100)).tostring("#.##")
      add-content -Path $strODFC_Main_Name -Value ("Percentage Space Empty::{0}" -f $strPercentage)
      add-content -Path $strODFC_Main_Name -Value ("Time::{0}" -f ( get-date -format T))
      add-content -Path $strODFC_Main_Name -Value ("Date::{0}" -f ( get-date -format D))
      add-content -Path $strODFC_Main_Name -Value ("DateTime::{0}" -f ( get-date -format o))
      } 
    }
  }
}

$objRegProfileSessions = gci -Path hklm:\software\fslogix\profiles\sessions -Recurse
ForEach ($objSubKeysProfile in $objRegProfileSessions)
{
$objIndividualProfileKey = Get-ItemProperty -path "registry::$objSubKeysProfile"
if ($objIndividualProfileKey.RefCount -ge 1 -and $objIndividualProfileKey.VHDOpenedFilePath -ne "" )
  {
  $strUserName = ""
  $strUserName = Get-ADUserName -strSID (Split-Path -path $objSubKeysProfile -Leaf)
  ForEach ($objVolume in $objVolumes)
    {
    if ($objIndividualProfileKey.volume -eq $objVolume.path)
      {
      #Get-ItemProperty -Path $objIndividualProfileKey.VHDOpenedFilePath | Format-List -Property *
      $objSizeOnDisk = Get-ItemProperty -Path $objIndividualProfileKey.VHDRootFilePath
      $strProfileParentPath = Split-Path -Path $objIndividualProfileKey.VHDOpenedFilePath -Parent
      $strProfile_VHD_Name = Split-Path -Path $objIndividualProfileKey.VHDOpenedFilePath -Leaf
      $strProfileBasePath = Split-Path -Path $strProfileParentPath -Parent
      $strProfileUserFolderName = Split-Path -Path $strProfileParentPath -Leaf
      $strProfileMGMTFolder = ("{0}\Mgmt" -f $strProfileBasePath)
      Folder-ExistOrCreate -strLocation $strProfileMGMTFolder
      $strProfile_Main_Name = ("{0}\Mgmt\{1}_Profile_main.txt" -f $strProfileBasePath, $strProfileUserFolderName)
      File-ExistOrCreate -strLocation $strProfile_Main_Name
      
      set-content -Path $strProfile_Main_Name -Value "VHD Name::$strProfile_VHD_Name"
      add-content -Path $strProfile_Main_Name -Value "Base Path::$strProfileBasePath"
      add-content -Path $strProfile_Main_Name -value ("VHD Folder::{0}" -f $strProfileUserFolderName )
      add-content -Path $strProfile_Main_Name -value ("User::{0}" -f $strUserName )
      add-content -Path $strProfile_Main_Name -value ("Computer::{0}" -f $Env:computername )
      add-content -Path $strProfile_Main_Name -value ("File System Label::{0}" -f $objVolume.FileSystemLabel)
      add-content -Path $strProfile_Main_Name -Value ("Space Remaining::{0}" -f $objVolume.SizeRemaining)
      add-content -Path $strProfile_Main_Name -value ("Volume Size::{0}" -f $objVolume.Size)
      $strPercentage = (($objVolume.SizeRemaining/$objVolume.Size) * 100).tostring("#.##")
      add-content -Path $strProfile_Main_Name -Value ("Percentage Space Remaining::{0}" -f $strPercentage)
      add-content -Path $strProfile_Main_Name -value ("Size on Disk::{0}" -f $objSizeOnDisk.Length)
      $strPercentage = ( 100 - ((($objVolume.Size - $objVolume.SizeRemaining)/$objSizeOnDisk.Length) * 100)).tostring("#.##")
      add-content -Path $strProfile_Main_Name -Value ("Percentage Space Empty::{0}" -f $strPercentage)
      add-content -Path $strProfile_Main_Name -Value ("Time::{0}" -f ( get-date -format T))
      add-content -Path $strProfile_Main_Name -Value ("Date::{0}" -f ( get-date -format D))
      add-content -Path $strProfile_Main_Name -Value ("DateTime::{0}" -f ( get-date -format o))

      $floatPercentage = (($objVolume.SizeRemaining/$objVolume.Size) * 100)
      If (  ($objVolume.SizeRemaining / 1024 / 1024) -lt $freeSpaceErrorThreshold ) {
        Write-EventLog -LogName "Application" -Source "FSLogix VHD Monitoring Script" -EventID 4001 -EntryType Error -Message "Container file $strProfileBasePath\$strProfileUserFolderName\$strProfile_VHD_Name for user $strUserName has $([math]::Round($objvolume.SizeRemaining/1024/1024,2)) MB free space remaining.  This is below the error threshold set ($freeSpaceWarningThreshold MB).  This may be causing issues with the user's Citrix session and/or Microsoft Office applications.  The size of the VHD/VHDX file should be increased immediately."
      }
      ElseIf (  ($objVolume.SizeRemaining / 1024 / 1024) -lt $freeSpaceWarningThreshold ) {

        Write-EventLog -LogName "Application" -Source "FSLogix VHD Monitoring Script" -EventID 4002 -EntryType Warning -Message "Container file $strProfileBasePath\$strProfileUserFolderName\$strProfile_VHD_Name for user $strUserName has $([math]::Round($objvolume.SizeRemaining/1024/1024,2)) MB free space remaining.  This is below the warning threshold set ($freeSpaceWarningThreshold MB).  The size of the VHD/VHDX file should be increased at the next opportunity."
      }
      Else {
        Write-EventLog -LogName "Application" -Source "FSLogix VHD Monitoring Script" -EventID 4003 -EntryType Information -Message "Container file $strProfileBasePath\$strProfileUserFolderName\$strProfile_VHD_Name for user $strUserName has $([math]::Round($objvolume.SizeRemaining/1024/1024,2)) MB free space remaining."
      }

      }
    }
  }
}
