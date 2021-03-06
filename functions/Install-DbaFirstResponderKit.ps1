function Install-DbaFirstResponderKit {
    <#
    .SYNOPSIS
        Installs or updates the First Responder Kit stored procedures.

    .DESCRIPTION
        Downloads, extracts and installs the First Responder Kit stored procedures:
        sp_Blitz, sp_BlitzWho, sp_BlitzFirst, sp_BlitzIndex, sp_BlitzCache and sp_BlitzTrace, etc.

        First Responder Kit links:
        http://FirstResponderKit.org
        https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Login to the target instance using alternative credentials. Windows and SQL Authentication supported. Accepts credential objects (Get-Credential)

    .PARAMETER Database
        Specifies the database to instal the First Responder Kit stored procedures into

    .PARAMETER Branch
        Specifies an alternate branch of the First Responder Kit to install. (master or dev)

    .PARAMETER LocalFile
        Specifies the path to a local file to install FRK from. This *should* be the zipfile as distributed by the maintainers.
        If this parameter is not specified, the latest version will be downloaded and installed from https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit

    .PARAMETER Force
        If this switch is enabled, the FRK will be downloaded from the internet even if previously cached.

    .PARAMETER Confirm
        Prompts to confirm actions

    .PARAMETER WhatIf
        Shows what would happen if the command were to run. No actions are actually performed.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: BrentOzar, FRK, FirstResponderKit
        Author: Tara Kizer, Brent Ozar Unlimited (https://www.brentozar.com/)

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Install-DbaFirstResponderKit

    .EXAMPLE
        PS C:\> Install-DbaFirstResponderKit -SqlInstance server1 -Database master

        Logs into server1 with Windows authentication and then installs the FRK in the master database.

    .EXAMPLE
        PS C:\> Install-DbaFirstResponderKit -SqlInstance server1\instance1 -Database DBA

        Logs into server1\instance1 with Windows authentication and then installs the FRK in the DBA database.

    .EXAMPLE
        PS C:\> Install-DbaFirstResponderKit -SqlInstance server1\instance1 -Database master -SqlCredential $cred

        Logs into server1\instance1 with SQL authentication and then installs the FRK in the master database.

    .EXAMPLE
        PS C:\> Install-DbaFirstResponderKit -SqlInstance sql2016\standardrtm, sql2016\sqlexpress, sql2014

        Logs into sql2016\standardrtm, sql2016\sqlexpress and sql2014 with Windows authentication and then installs the FRK in the master database.

    .EXAMPLE
        PS C:\> $servers = "sql2016\standardrtm", "sql2016\sqlexpress", "sql2014"
        PS C:\> $servers | Install-DbaFirstResponderKit

        Logs into sql2016\standardrtm, sql2016\sqlexpress and sql2014 with Windows authentication and then installs the FRK in the master database.

    .EXAMPLE
        PS C:\> Install-DbaFirstResponderKit -SqlInstance sql2016 -Branch dev

        Installs the dev branch version of the FRK in the master database on sql2016 instance.

    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [ValidateSet('master', 'dev')]
        [string]$Branch = "master",
        [object]$Database = "master",
        [string]$LocalFile,
        [switch]$Force,
        [switch]$EnableException
    )

    begin {
        if ($Force) {$ConfirmPreference = 'none'}

        $DbatoolsData = Get-DbatoolsConfigValue -FullName "Path.DbatoolsData"

        if (-not $DbatoolsData) {
            $DbatoolsData = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
        }

        $url = "https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/archive/$Branch.zip"

        $temp = ([System.IO.Path]::GetTempPath()).TrimEnd("\")
        $zipfile = "$temp\SQL-Server-First-Responder-Kit-$Branch.zip"
        $zipfolder = "$temp\SQL-Server-First-Responder-Kit-$Branch\"
        $FRKLocation = "FRK_$Branch"
        $LocalCachedCopy = Join-Path -Path $DbatoolsData -ChildPath $FRKLocation
        if ($LocalFile) {
            if (-not(Test-Path $LocalFile)) {
                Stop-Function -Message "$LocalFile doesn't exist"
                return
            }
            if (-not($LocalFile.EndsWith('.zip'))) {
                Stop-Function -Message "$LocalFile should be a zip file"
                return
            }
        }

        if ($Force -or -not(Test-Path -Path $LocalCachedCopy -PathType Container) -or $LocalFile) {
            # Force was passed, or we don't have a local copy, or $LocalFile was passed
            if ($zipfile | Test-Path) {
                Remove-Item -Path $zipfile -ErrorAction SilentlyContinue
            }
            if ($zipfolder | Test-Path) {
                Remove-Item -Path $zipfolder -Recurse -ErrorAction SilentlyContinue
            }

            $null = New-Item -ItemType Directory -Path $zipfolder -ErrorAction SilentlyContinue
            if ($LocalFile) {
                Unblock-File $LocalFile -ErrorAction SilentlyContinue
                Expand-Archive -Path $LocalFile -DestinationPath $zipfolder -Force
            } else {
                Write-Message -Level Verbose -Message "Downloading and unzipping the First Responder Kit zip file."

                try {

                    try {
                        Invoke-TlsWebRequest $url -OutFile $zipfile -ErrorAction Stop -UseBasicParsing
                    } catch {
                        # Try with default proxy and usersettings
                        (New-Object System.Net.WebClient).Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
                        Invoke-TlsWebRequest $url -OutFile $zipfile -ErrorAction Stop -UseBasicParsing
                    }


                    # Unblock if there's a block
                    Unblock-File $zipfile -ErrorAction SilentlyContinue

                    Expand-Archive -Path $zipfile -DestinationPath $zipfolder -Force

                    Remove-Item -Path $zipfile
                } catch {
                    Stop-Function -Message "Couldn't download the First Responder Kit. Download and install manually from https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/archive/$Branch.zip." -ErrorRecord $_
                    return
                }
            }

            ## Copy it into local area
            if (Test-Path -Path $LocalCachedCopy -PathType Container) {
                Remove-Item -Path (Join-Path $LocalCachedCopy '*') -Recurse -ErrorAction SilentlyContinue
            } else {
                $null = New-Item -Path $LocalCachedCopy -ItemType Container
            }
            Copy-Item -Path $zipfolder -Destination $LocalCachedCopy -Recurse
        }
    }


    process {
        if (Test-FunctionInterrupt) {
            return
        }

        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $sqlcredential
            } catch {
                Stop-Function -Message "Failure." -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            Write-Message -Level Verbose -Message "Starting installing/updating the First Responder Kit stored procedures in $database on $instance."
            $allprocedures_query = "select name from sys.procedures where is_ms_shipped = 0"
            $allprocedures = ($server.Query($allprocedures_query, $Database)).Name
            # Install/Update each FRK stored procedure
            foreach ($script in (Get-ChildItem $LocalCachedCopy -Recurse -Filter "sp_*.sql")) {
                $scriptname = $script.Name
                $scriptError = $false
                if ($scriptname -ne "sp_BlitzRS.sql") {

                    if ($scriptname -eq "sp_BlitzQueryStore.sql") {
                        if ($server.VersionMajor -lt 13) { continue }
                    }
                    if ($Pscmdlet.ShouldProcess($instance, "installing/updating $scriptname in $database.")) {
                        try {
                            Invoke-DbaQuery -SqlInstance $server -Database $Database -File $script.FullName -EnableException -Verbose:$false
                        } catch {
                            Write-Message -Level Warning -Message "Could not execute at least one portion of $scriptname in $Database on $instance." -ErrorRecord $_
                            $scriptError = $true
                        }
                        $baseres = @{
                            ComputerName = $server.ComputerName
                            InstanceName = $server.ServiceName
                            SqlInstance  = $server.DomainInstanceName
                            Database     = $Database
                            Name         = $script.BaseName
                        }
                        if ($scriptError) {
                            $baseres['Status'] = 'Error'
                        } elseif ($script.BaseName -in $allprocedures) {
                            $baseres['Status'] = 'Updated'
                        } else {
                            $baseres['Status'] = 'Installed'
                        }
                        [PSCustomObject]$baseres
                    }
                }
            }
            Write-Message -Level Verbose -Message "Finished installing/updating the First Responder Kit stored procedures in $database on $instance."
        }
    }
}