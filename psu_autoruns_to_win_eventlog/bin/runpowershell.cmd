@ECHO OFF

:: ######################################################
:: # copied from:
:: # Splunk for Microsoft Active Directory
:: # 
:: # Copyright (C) 2016 Splunk, Inc.
:: # All Rights Reserved
:: #
:: ######################################################

set SplunkApp=psu_autoruns_to_win_eventlog

%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe -executionPolicy Unrestricted -command ". '%SPLUNK_HOME%\etc\apps\%SplunkApp%\bin\AutorunsToWinEventLog.ps1'"
