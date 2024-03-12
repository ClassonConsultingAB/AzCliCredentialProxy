param(
    [switch]$SkipPush,
    [string]$Version = $null,
    [string]$GitHubPat = $env:GitHubPat,
    [string]$Organization = 'ClassonConsultingAB',
    [string]$Repository = 'AzCliCredentialProxy',
    [string]$Registry = 'ghcr.io'
)

$ErrorActionPreference = 'Stop'

import-module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$rootPath = Resolve-Path "$PSScriptRoot/.."
$outputDirPath = Join-Path $rootPath output
$versionFilePath = Join-Path $outputDirPath version.json
$imageName = $Repository.ToLower()
if (Test-Path $outputDirPath) { Remove-Item $outputDirPath -Recurse }
New-Item $outputDirPath -ItemType Directory | Out-Null
Install-GitVersion
Exec "dotnet-gitversion $rootPath /output file /outputfile $versionFilePath"
$versionInfo = (Get-Content $versionFilePath | ConvertFrom-Json)

if ([string]::IsNullOrEmpty($Version)) {
    if ([string]::IsNullOrEmpty($versionInfo.PreReleaseTag)) {
        $preRelease = $false
    }
    else {
        $preRelease = $true
    }
    $containerImageVersion = "v$($versionInfo.LegacySemVerPadded)"
}
else {
    $containerImageVersion = "v$Version"
    $preRelease = $false
}

function Get-ImageWithTag($Tag) {
    return '{0}:{1}' -f $imageName, $Tag
}

$images = [System.Collections.ArrayList]@()

Task -Title Build -Command {
    $imageWithTag = Get-ImageWithTag $containerImageVersion
    $images.Add($imageWithTag) | Out-Null
    $build_args = @(
        "--build-arg GITHUB_SOURCE_PASSWORD=$GitHubPat",
        "--label org.opencontainers.image.title=$Repository"
        '--label org.opencontainers.image.description='
        "--label org.opencontainers.image.url=https://github.com/$Organization/$Repository"
        "--label org.opencontainers.image.source=https://github.com/$Organization/$Repository"
        "--label org.opencontainers.image.version=$containerImageVersion"
        "--label org.opencontainers.image.created=$([DateTime]::UtcNow.ToString('o'))"
        "--label org.opencontainers.image.revision=$($versionInfo.ShortSha)"
        '--label org.opencontainers.image.licenses=MIT'
        "-t $imageWithTag"
    )
    Exec "docker build $($build_args -join ' ') $rootPath"
    if (!$preRelease) {
        $versionParts = $containerImageVersion.Split('.')
        for ($i = 1; $i -lt $versionParts.Count; $i++) {
            $helperImageWithTag = Get-ImageWithTag (($versionParts | Select-Object -First $i) -join '.')
            $images.Add($helperImageWithTag) | Out-Null
            Exec "docker tag $imageWithTag $helperImageWithTag"
        }
    }
}

Task -Title Push -Skip:$SkipPush -Command {
    Exec "echo $GitHubPat | docker login $Registry -u automation --password-stdin"
    foreach ($image in $images) {
        $gitHubImage = "$Registry/$($Organization.ToLower())/$image"
        Exec "docker tag $image $gitHubImage"
        Exec "docker push $gitHubImage"
        Exec "docker rmi $gitHubImage"
    }
}

Write-TaskSummary
