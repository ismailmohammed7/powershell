<#
.SYNOPSIS
    Export Azure SQL Database to Blob storage and download the exported *.bacpac file from blob to local path
.DESCRIPTION
    This PowerShell Script to export Azure SQL DB to a blob storage and then copies blobs from a single storage container to a local directoy. 
    
.EXAMPLE
    .\CopyFilesFromAzureStorageContainer -LocalPath "c:\" -ServerName "myservername" -DatabaseName "myDBname" -ResourceGroupName "myresourcegroupname" -StorageAccountName "mystorageaccount" -ContainerName "myuserdocuments" -Force
#>;

        $DatabaseName = "AdventureWorksLT"
		$CopyDatabaseName = "AdventureWorksLT_Copy"
        $ServerName = "zvydbs"
        $ResourceGroupName = "kmd-logic-dev-zvy-rg"
        $StorageAccountName = "zvylogicstorage"
        $ContainerName = "adventureworksdbackup"
        $LocalPath = "D:\"
         
         
        # Create azure login credential
        $Credential = Get-Credential
        Connect-AzureRmAccount -Credential $Credential

		
		# Create Copy Database
		New-AzureRmSqlDatabaseCopy -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName -CopyResourceGroupName $ResourceGroupName -CopyServerName $ServerName -CopyDatabaseName $CopyDatabaseName
         
        Write-Output "Azure SQL DB $CopyDatabaseName Copy completed"
 

        # Generate a unique filename for the BACPAC
        $bacpacFilename = "$DatabaseName" + (Get-Date).ToString("yyyy-MM-dd-HH-mm") + ".bacpac"
 
        # Blob storage information
        $StorageKey = "SM0T7/PWY3WVFU/J3VIVOv1dLxjLSV8Mxv9w9wgPIYReuMsUw6fAOObFIms40vEOQNbifoYOSy6nfQAgcCuKdg=="
        $BaseStorageUri = "https://zvylogicstorage.blob.core.windows.net/adventureworksdbackup/"
        $BacPacUri = $BaseStorageUri + $bacpacFilename
        

        # Create sql admin authentication credential
        $AdministratorCredential = Get-Credential

        # Export to Blob container
        $Request = New-AzureRmSqlDatabaseExport –ResourceGroupName $ResourceGroupName –ServerName $ServerName –DatabaseName $DatabaseName –StorageKeytype StorageAccessKey –StorageKey $StorageKey -StorageUri $BacPacUri –AdministratorLogin $AdministratorCredential.UserName –AdministratorLoginPassword $AdministratorCredential.Password
 
        # Check status of the export
        $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $Request.OperationStatusLink
        [Console]::Write("Exporting")
        while ($exportStatus.Status -eq "InProgress")
        {
        $exportStatus = Get-AzureRmSqlDatabaseImportExportStatus -OperationStatusLink $Request.OperationStatusLink
        Start-Sleep -s 10
        }
        $exportStatus
        $Status= $exportStatus.Status
        if($Status -eq "Succeeded")
        {
        Write-Output "Azure SQL DB Export $Status for "$DatabaseName""
        }
        else
        {
        Write-Output "Azure SQL DB Export Failed for "$DatabaseName""
        }


		# Create azure login credential
        $Credential = Get-Credential
        Connect-AzureRmAccount -Credential $Credential

		# Download file from azure
        Write-Output "Downloading"
        $StorageContext = Get-AzureRmStorageAccount -Name $StorageAccountName -ResourceGroupName $ResourceGroupName 
        $StorageContext | Get-AzureStorageBlob -Container $ContainerName -blob $bacpacFilename | Get-AzureStorageBlobContent -Destination $LocalPath
        $Status= $exportStatus.Status
        if($Status -eq "Succeeded")
        {
        Write-Output "Blob $bacpacFilename Download $Status for "$DatabaseName" To $LocalPath"
        }
        else
        {
        Write-Output "Blob $bacpacFilename Download Failed for "$DatabaseName""
        } 
 
        # Drop Copy Database after successful export
        Remove-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $CopyDatabaseName -Force
          
        Write-Output "Azure SQL DB $CopyDatabaseName Deleted"
             
