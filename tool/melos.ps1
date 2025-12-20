#!/usr/bin/env pwsh
[CmdletBinding()]
param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$MelosArgs
)

$ErrorActionPreference = 'Stop'

& fvm dart run melos @MelosArgs
exit $LASTEXITCODE

