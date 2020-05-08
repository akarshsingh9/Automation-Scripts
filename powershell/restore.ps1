param(
$LPDatabaseServer,
$TargetDBs,
$BackUpDBSourcePath
)
Function getLogicalFileNames($path,$LPDatabaseServer){
$MasterDatabase="master"
$sql=@"
DECLARE @Table TABLE (LogicalName varchar(128),[PhysicalName] varchar(128), [Type] varchar, [FileGroupName] varchar(128), [Size] varchar(128),[MaxSize] varchar(128), [FileId]varchar(128), [CreateLSN]varchar(128), [DropLSN]varchar(128), [UniqueId]varchar(128), [ReadOnlyLSN]varchar(128), [ReadWriteLSN]varchar(128),[BackupSizeInBytes]varchar(128), [SourceBlockSize]varchar(128), [FileGroupId]varchar(128), [LogGroupGUID]varchar(128), [DifferentialBaseLSN]varchar(128), [DifferentialBaseGUID]varchar(128), [IsReadOnly]varchar(128), [IsPresent]varchar(128), [TDEThumbprint]varchar(128),[SnapshotUrl] varchar(128))
DECLARE @Path varchar(1000)=N'$path'
DECLARE @LogicalNameData varchar(128),@LogicalNameLog varchar(128)
INSERT INTO @Table EXEC('
RESTORE FILELISTONLY 
FROM DISK=''' +@Path+ '''
')
SET @LogicalNameData=(SELECT LogicalName FROM @Table WHERE Type='D')
SET @LogicalNameLog=(SELECT LogicalName FROM @Table WHERE Type='L')
SELECT Datafilename=@LogicalNameData,LogFilename=@LogicalNameLog
"@
$Filenames=Invoke-Sqlcmd -ServerInstance $LPDatabaseServer -Database $MasterDatabase  -Query $sql -ConnectionTimeout 77777 -QueryTimeout 77777
write $thisValue
return $Filenames
}
Function checkDBExists($database,$LPDatabaseServer){
$sql = "
SELECT name FROM master.dbo.sysdatabases"
$DBList  = Invoke-Sqlcmd -ServerInstance $LPDatabaseServer  -query $sql -ConnectionTimeout 77777 -QueryTimeout 77777
$exist = $false
foreach($db in $DBList)
{
if($db.name -eq $database)
{
$exist = $true
break
}
}
return $exist
}
function RestoringDB($database,$LPDatabaseServer,$DBSourcePath,$DataFileLogicalName,$LogFileLogicalName)
{
$MasterDatabase="master"
$logFileName = $database+'_log.ldf'
$sql = @"
USE [master]
Go
ALTER DATABASE [$database]
SET SINGLE_USER WITH ROLLBACK IMMEDIATE
RESTORE DATABASE [$database]
FROM DISK = N'$DBSourcePath'
WITH FILE = 1,
MOVE '$DataFileLogicalName' TO 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\DATA\$database.mdf',
MOVE '$LogFileLogicalName' TO 'C:\Program Files\Microsoft SQL Server\MSSQL14.MSSQLSERVER\MSSQL\Log\$logFileName',
RECOVERY, REPLACE, STATS = 5
ALTER DATABASE [$database]
SET MULTI_USER
"@
Invoke-Sqlcmd -ServerInstance $LPDatabaseServer -Database $MasterDatabase  -Query $sql -ConnectionTimeout 77777 -QueryTimeout 77777
write $thisValue
}

$TargetDBs=$TargetDBs.Split(',')

foreach($TargetDB in $TargetDBs)
{
$json = '
{
"Servers": [{
"Servername":  "'+$LPDatabaseServer+'",
"Databases": [{
"DBName":  "'+$TargetDB+'",
"DBBackupSourcePath":  "'+$BackUpDBSourcePath+'"
}
]
}]
}'
$jsonObject=$null
$LPDatabaseServer=$null
$server=$null
$Filenames=$null
$DataFileLogicalName=$null
$LogFileLogicalName=$null
$exist=$false
$database =$null
$DBSourcePath = $null
$jsonObject=ConvertFrom-Json -InputObject $json
foreach($server in $jsonObject.Servers){
$LPDatabaseServer=$server.Servername
$server.Databases | ForEach-Object{
$database = $_.DBName
$DBSourcePath = $_.DBBackupSourcePath
$Filenames=getLogicalFileNames $DBSourcePath $LPDatabaseServer
$DataFileLogicalName=$Filenames.Datafilename
$LogFileLogicalName=$Filenames.LogFilename
$exist=checkDBExists $database $LPDatabaseServer
if($exist -eq $true)
{
Write-host "`r`n"$database
Write-Host "Database Already Exist"
Write-Host "Now Restoring..."
RestoringDB $database $LPDatabaseServer $DBSourcePath $DataFileLogicalName $LogFileLogicalName
write-host "Restored"
}
else
{
$sql = @"
USE [master]
Go
Create DataBase $database
"@
Invoke-Sqlcmd -ServerInstance $LPDatabaseServer  -query $sql -ConnectionTimeout 77777 -QueryTimeout 77777
write-host "DB Created"
Write-Host "Now Restoring..."
RestoringDB $database $LPDatabaseServer $DBSourcePath $DataFileLogicalName $LogFileLogicalName
 write-host "Restored"
}
}
}

}