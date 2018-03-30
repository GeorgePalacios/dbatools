#ValidationTags#Messaging#
function Copy-DbaAgentCategory {
    <#
        .SYNOPSIS
            Copy-DbaAgentCategory migrates SQL Agent categories from one SQL Server to another. This is similar to sp_add_category.

            https://msdn.microsoft.com/en-us/library/ms181597.aspx

        .DESCRIPTION
            By default, all SQL Agent categories for Jobs, Operators and Alerts are copied.

            The -OperatorCategories parameter is auto-populated for command-line completion and can be used to copy only specific operator categories.
            The -AgentCategories parameter is auto-populated for command-line completion and can be used to copy only specific agent categories.
            The -JobCategories parameter is auto-populated for command-line completion and can be used to copy only specific job categories.

            If the category already exists on the destination, it will be skipped unless -Force is used.

        .PARAMETER Source
            Source SQL Server. You must have sysadmin access and server version must be SQL Server version 2000 or higher.

        .PARAMETER SourceSqlCredential
            Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

        .PARAMETER Destination
            Destination SQL Server. You must have sysadmin access and the server must be SQL Server 2000 or higher.

        .PARAMETER DestinationSqlCredential
            Allows you to login to servers using SQL Logins instead of Windows Authentication (AKA Integrated or Trusted). To use:

            $dcred = Get-Credential, then pass this $dcred to the -DestinationSqlCredential parameter.

            Windows Authentication will be used if DestinationSqlCredential is not specified. SQL Server does not accept Windows credentials being passed as credentials.

            To connect as a different Windows user, run PowerShell as that user.

        .PARAMETER CategoryType
            Specifies the Category Type to migrate. Valid options are "Job", "Alert" and "Operator". When CategoryType is specified, all categories from the selected type will be migrated. For granular migrations, use the three parameters below.

        .PARAMETER OperatorCategory
            This parameter is auto-populated for command-line completion and can be used to copy only specific operator categories.

        .PARAMETER AgentCategory
            This parameter is auto-populated for command-line completion and can be used to copy only specific agent categories.

        .PARAMETER JobCategory
            This parameter is auto-populated for command-line completion and can be used to copy only specific job categories.

        .PARAMETER WhatIf
            If this switch is enabled, no actions are performed but informational messages will be displayed that explain what would happen if the command were to run.

        .PARAMETER Confirm
            If this switch is enabled, you will be prompted for confirmation before executing any operations that change state.

        .PARAMETER Force
            If this switch is enabled, the Category will be dropped and recreated on Destination.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Tags: Migration, Agent
            Author: Chrissy LeMaire (@cl), netnerds.net
            Requires: sysadmin access on SQL Servers

            Website: https://dbatools.io
            Copyright: (C) Chrissy LeMaire, clemaire@gmail.com
            License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Copy-DbaAgentCategory

        .EXAMPLE
            Copy-DbaAgentCategory -Source sqlserver2014a -Destination sqlcluster

            Copies all operator categories from sqlserver2014a to sqlcluster using Windows authentication. If operator categories with the same name exist on sqlcluster, they will be skipped.

        .EXAMPLE
            Copy-DbaAgentCategory -Source sqlserver2014a -Destination sqlcluster -OperatorCategory PSOperator -SourceSqlCredential $cred -Force

            Copies a single operator category, the PSOperator operator category from sqlserver2014a to sqlcluster using SQL credentials to authenticate to sqlserver2014a and Windows credentials for sqlcluster. If a operator category with the same name exists on sqlcluster, it will be dropped and recreated because -Force was used.

        .EXAMPLE
            Copy-DbaAgentCategory -Source sqlserver2014a -Destination sqlcluster -WhatIf -Force

            Shows what would happen if the command were executed using force.
    #>
    [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldprocess = $true)]
    param (
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Source,
        [PSCredential]
        $SourceSqlCredential,
        [parameter(Mandatory = $true)]
        [DbaInstanceParameter]$Destination,
        [PSCredential]
        $DestinationSqlCredential,
        [Parameter(ParameterSetName = 'SpecificAlerts')]
        [ValidateSet('Job', 'Alert', 'Operator')]
        [string[]]$CategoryType,
        [string[]]$JobCategory,
        [string[]]$AgentCategory,
        [string[]]$OperatorCategory,
        [switch]$Force,
        [Alias('Silent')]
        [switch]$EnableException
    )

    begin {
        function Copy-JobCategory {
            <#
                .SYNOPSIS
                    Copy-JobCategory migrates job categories from one SQL Server to another.

                .DESCRIPTION
                    By default, all job categories are copied. The -JobCategories parameter is auto-populated for command-line completion and can be used to copy only specific job categories.

                    If the associated credential for the category does not exist on the destination, it will be skipped. If the job category already exists on the destination, it will be skipped unless -Force is used.
            #>
            param (
                [string[]]$jobCategories
            )

            process {

                $serverJobCategories = $sourceServer.JobServer.JobCategories | Where-Object ID -ge 100
                $destJobCategories = $destServer.JobServer.JobCategories | Where-Object ID -ge 100

                foreach ($jobCategory in $serverJobCategories) {
                    $categoryName = $jobCategory.Name

                    $copyJobCategoryStatus = [pscustomobject]@{
                        SourceServer      = $sourceServer.Name
                        DestinationServer = $destServer.Name
                        Name              = $categoryName
                        Type              = "Agent Job Category"
                        Status            = $null
                        Notes             = $null
                        DateTime          = [Sqlcollaborative.Dbatools.Utility.DbaDateTime](Get-Date)
                    }

                    if ($jobCategories.Count -gt 0 -and $jobCategories -notcontains $categoryName) {
                        continue
                    }

                    if ($destJobCategories.Name -contains $jobCategory.name) {
                        if ($force -eq $false) {
                            $copyJobCategoryStatus.Status = "Skipped"
                            $copyJobCategoryStatus.Notes = "Already exists"
                            $copyJobCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            Write-Message -Level Verbose -Message "Job category $categoryName exists at destination. Use -Force to drop and migrate."
                            continue
                        }
                        else {
                            if ($Pscmdlet.ShouldProcess($destination, "Dropping job category $categoryName")) {
                                try {
                                    Write-Message -Level Verbose -Message "Dropping Job category $categoryName"
                                    $destServer.JobServer.JobCategories[$categoryName].Drop()
                                }
                                catch {
                                    $copyJobCategoryStatus.Status = "Failed"
                                    $copyJobCategoryStatus
                                    Stop-Function -Message "Issue dropping job category" -Target $categoryName -InnerErrorRecord $_ -Continue
                                }
                            }
                        }
                    }

                    if ($Pscmdlet.ShouldProcess($destination, "Creating Job category $categoryName")) {
                        try {
                            Write-Message -Level Verbose -Message "Copying Job category $categoryName"
                            $sql = $jobCategory.Script() | Out-String
                            Write-Message -Level Debug -Message "SQL Statement: $sql"
                            $destServer.Query($sql)

                            $copyJobCategoryStatus.Status = "Successful"
                            $copyJobCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                        }
                        catch {
                            $copyJobCategoryStatus.Status = "Failed"
                            $copyJobCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            Stop-Function -Message "Issue copying job category" -Target $categoryName -InnerErrorRecord $_
                        }
                    }
                }
            }
        }

        function Copy-OperatorCategory {
            <#
                .SYNOPSIS
                    Copy-OperatorCategory migrates operator categories from one SQL Server to another.

                .DESCRIPTION
                    By default, all operator categories are copied. The -OperatorCategories parameter is auto-populated for command-line completion and can be used to copy only specific operator categories.

                    If the associated credential for the category does not exist on the destination, it will be skipped. If the operator category already exists on the destination, it will be skipped unless -Force is used.
            #>
            [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldprocess = $true)]
            param (
                [string[]]$operatorCategories
            )
            process {
                $serverOperatorCategories = $sourceServer.JobServer.OperatorCategories | Where-Object ID -ge 100
                $destOperatorCategories = $destServer.JobServer.OperatorCategories | Where-Object ID -ge 100

                foreach ($operatorCategory in $serverOperatorCategories) {
                    $categoryName = $operatorCategory.Name

                    $copyOperatorCategoryStatus = [pscustomobject]@{
                        SourceServer      = $sourceServer.Name
                        DestinationServer = $destServer.Name
                        Type              = "Agent Operator Category"
                        Name              = $categoryName
                        Status            = $null
                        Notes             = $null
                        DateTime          = [Sqlcollaborative.Dbatools.Utility.DbaDateTime](Get-Date)
                    }

                    if ($operatorCategories.Count -gt 0 -and $operatorCategories -notcontains $categoryName) {
                        continue
                    }

                    if ($destOperatorCategories.Name -contains $operatorCategory.Name) {
                        if ($force -eq $false) {
                            $copyOperatorCategoryStatus.Status = "Skipped"
                            $copyOperatorCategoryStatus.Notes = "Already exists"
                            $copyOperatorCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            Write-Message -Level Verbose -Message "Operator category $categoryName exists at destination. Use -Force to drop and migrate."
                            continue
                        }
                        else {
                            if ($Pscmdlet.ShouldProcess($destination, "Dropping operator category $categoryName and recreating")) {
                                try {
                                    Write-Message -Level Verbose -Message "Dropping Operator category $categoryName"
                                    $destServer.JobServer.OperatorCategories[$categoryName].Drop()
                                    Write-Message -Level Verbose -Message "Copying Operator category $categoryName"
                                    $sql = $operatorCategory.Script() | Out-String
                                    Write-Message -Level Debug -Message $sql
                                    $destServer.Query($sql)
                                }
                                catch {
                                    $copyOperatorCategoryStatus.Status = "Failed"
                                    $copyOperatorCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                                    Stop-Function -Message "Issue dropping operator category" -Target $categoryName -InnerErrorRecord $_
                                }
                            }
                        }
                    }
                    else {
                        if ($Pscmdlet.ShouldProcess($destination, "Creating Operator category $categoryName")) {
                            try {
                                Write-Message -Level Verbose -Message "Copying Operator category $categoryName"
                                $sql = $operatorCategory.Script() | Out-String
                                Write-Message -Level Debug -Message $sql
                                $destServer.Query($sql)

                                $copyOperatorCategoryStatus.Status = "Successful"
                                $copyOperatorCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                            }
                            catch {
                                $copyOperatorCategoryStatus.Status = "Failed"
                                $copyOperatorCategoryStatus | Select-DefaultView -Property DateTime, SourceServer, DestinationServer, Name, Type, Status, Notes -TypeName MigrationObject
                                Stop-Function -Message "Issue copying operator category" -Target $categoryName -InnerErrorRecord $_
                            }
                        }
                    }
                }
            }
        }

        function Copy-AlertCategory {
            <#
                .SYNOPSIS
                    Copy-AlertCategory migrates alert categories from one SQL Server to another.

                .DESCRIPTION
                    By default, all alert categories are copied. The -AlertCategories parameter is auto-populated for command-line completion and can be used to copy only specific alert categories.

                    If the associated credential for the category does not exist on the destination, it will be skipped. If the alert category already exists on the destination, it will be skipped unless -Force is used.
            #>
            [CmdletBinding(DefaultParameterSetName = "Default", SupportsShouldprocess = $true)]
            param (
                [string[]]$AlertCategories
            )

            process {
                if ($sourceServer.VersionMajor -lt 9 -or $destServer.VersionMajor -lt 9) {
                    throw "Server AlertCategories are only supported in SQL Server 2005 and above. Quitting."
                }

                $serverAlertCategories = $sourceServer.JobServer.AlertCategories | Where-Object ID -ge 100
                $destAlertCategories = $destServer.JobServer.AlertCategories | Where-Object ID -ge 100

                foreach ($alertCategory in $serverAlertCategories) {
                    $categoryName = $alertCategory.Name

                    $copyAlertCategoryStatus = [pscustomobject]@{
                        SourceServer      = $sourceServer.Name
                        DestinationServer = $destServer.Name
                        Type              = "Agent Alert Category"
                        Name              = $categoryName
                        Status            = $null
                        Notes             = $null
                        DateTime          = [Sqlcollaborative.Dbatools.Utility.DbaDateTime](Get-Date)
                    }

                    if ($alertCategories.Length -gt 0 -and $alertCategories -notcontains $categoryName) {
                        continue
                    }

                    if ($destAlertCategories.Name -contains $alertCategory.name) {
                        if ($force -eq $false) {
                            $copyAlertCategoryStatus.Status = "Skipped"
                            $copyAlertCategoryStatus.Notes = "Already exists"
                            $copyAlertCategoryStatus
                            Write-Message -Level Verbose -Message "Alert category $categoryName exists at destination. Use -Force to drop and migrate."
                            continue
                        }
                        else {
                            if ($Pscmdlet.ShouldProcess($destination, "Dropping alert category $categoryName and recreating")) {
                                try {
                                    Write-Message -Level Verbose -Message "Dropping Alert category $categoryName"
                                    $destServer.JobServer.AlertCategories[$categoryName].Drop()
                                    Write-Message -Level Verbose -Message "Copying Alert category $categoryName"
                                    $sql = $alertcategory.Script() | Out-String
                                    Write-Message -Level Debug -Message "SQL Statement: $sql"
                                    $destServer.Query($sql)
                                }
                                catch {
                                    $copyAlertCategoryStatus.Status = "Failed"
                                    $copyAlertCategoryStatus
                                    Stop-Function -Message "Issue dropping alert category" -Target $categoryName -InnerErrorRecord $_
                                }
                            }
                        }
                    }
                    else {
                        if ($Pscmdlet.ShouldProcess($destination, "Creating Alert category $categoryName")) {
                            try {
                                Write-Message -Level Verbose -Message "Copying Alert category $categoryName"
                                $sql = $alertCategory.Script() | Out-String
                                Write-Message -Level Debug -Message $sql
                                $destServer.Query($sql)

                                $copyAlertCategoryStatus.Status = "Successful"
                                $copyAlertCategoryStatus
                            }
                            catch {
                                $copyAlertCategoryStatus.Status = "Failed"
                                $copyAlertCategoryStatus
                                Stop-Function -Message "Issue creating alert category" -Target $categoryName -InnerErrorRecord $_
                            }
                        }
                    }
                }
            }
        }

        $sourceServer = Connect-SqlInstance -SqlInstance $Source -SqlCredential $SourceSqlCredential
        $destServer = Connect-SqlInstance -SqlInstance $Destination -SqlCredential $DestinationSqlCredential

        $source = $sourceServer.DomainInstanceName
        $destination = $destServer.DomainInstanceName

    }
    process {
        if ($CategoryType.count -gt 0) {

            switch ($CategoryType) {
                "Job" {
                    Copy-JobCategory
                }

                "Alert" {
                    Copy-AlertCategory
                }

                "Operator" {
                    Copy-OperatorCategory
                }
            }

            return
        }

        if (($OperatorCategory.Count + $AlertCategory.Count + $jobCategory.Count) -gt 0) {

            if ($OperatorCategory.Count -gt 0) {
                Copy-OperatorCategory -OperatorCategories $OperatorCategory
            }

            if ($AlertCategory.Count -gt 0) {
                Copy-AlertCategory -AlertCategories $AlertCategory
            }

            if ($jobCategory.Count -gt 0) {
                Copy-JobCategory -JobCategories $jobCategory
            }

            return
        }

        Copy-OperatorCategory
        Copy-AlertCategory
        Copy-JobCategory
    }
    end {
        Test-DbaDeprecation -DeprecatedOn "1.0.0" -EnableException:$false -Alias Copy-SqlAgentCategory
    }
}
