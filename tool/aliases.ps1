<#
在仓库任意目录执行（PowerShell）：
  . C:\path\to\fcmp\tool\aliases.ps1

建议写进 PowerShell Profile（$PROFILE）：
  $repo = 'C:\path\to\fcmp'
  $aliases = Join-Path $repo 'tool\aliases.ps1'
  if (Test-Path $aliases) { . $aliases }

注意：PowerShell 的 alias 不能自动透传参数，所以这里用 function + Set-Alias。
#>

function Invoke-Melos {
  param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
  )

  & fvm dart run melos @Args
  return $LASTEXITCODE
}

Set-Alias melos Invoke-Melos
Set-Alias mm Invoke-Melos

