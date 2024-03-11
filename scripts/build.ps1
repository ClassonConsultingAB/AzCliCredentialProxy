param(
    [switch]$SkipPush,
    [string]$Version = $null,
    [string]$RegistryPrefix = 'gchr.io/classonconsultingab',
    [string]$RepositoryUrl = 'https://github.com/ClassonConsultingAB/AzCliCredentialProxy',
    [string]$GitHubPat = $env:GitHubPat
)

$ErrorActionPreference = 'Stop'

import-module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$root = Resolve-Path "$PSScriptRoot/.."
$imageName = 'azure-cli-credential-proxy'

if ([string]::IsNullOrEmpty($Version)) {
    $sha = Exec { git rev-parse --short HEAD } -ReturnOutput
    $containerImageVersion = $sha
}
else {
    $containerImageVersion = "v$Version"
}

function Get-ImageWithTag($Tag) {
    return '{0}:{1}' -f $imageName, $Tag
}

$images = [System.Collections.ArrayList]@()

Task -Title Build -Command {
    $imageWithTag = Get-ImageWithTag $containerImageVersion
    $images.Add($imageWithTag) | Out-Null
    Exec "docker build --build-arg GITHUB_SOURCE_PASSWORD=$GitHubPat -t $imageWithTag --label 'org.opencontainers.image.source=$RepositoryUrl' $root"
    $versionParts = $containerImageVersion.Split('.')
    for ($i = 1; $i -lt $versionParts.Count; $i++) {
        $helperImageWithTag = Get-ImageWithTag (($versionParts | Select-Object -First $i) -join '.')
        $images.Add($helperImageWithTag) | Out-Null
        Exec "docker tag $imageWithTag $helperImageWithTag"
    }
}

Task -Title Push -Skip:$SkipPush -Command {
    Exec "echo $GitHubPat | docker login ghcr.io -u USERNAME --password-stdin"
    foreach ($image in $images) {
        $gitHubImage = "$RegistryPrefix/$image"
        Exec "docker tag $image $gitHubImage"
        Exec "docker push $gitHubImage"
        Exec "docker rmi $gitHubImage"
    }
}

Write-TaskSummary
