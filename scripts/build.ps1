param(
    [switch]$SkipPush,
    [string]$Version = $null,
    [string]$RegistryPrefix = 'gchr.io/classonconsultingab',
    [string]$GitHubPat = $env:GitHubPat
)

$ErrorActionPreference = 'Stop'

import-module "$PSScriptRoot/modules/BuildTasks/BuildTasks.psm1" -Force

$root = Resolve-Path "$PSScriptRoot/.."
$imageName = 'azclicredentialproxy'
$sha = Exec { git rev-parse --short HEAD } -ReturnOutput

if ([string]::IsNullOrEmpty($Version)) {
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
    $build_args = @(
        "--build-arg GITHUB_SOURCE_PASSWORD=$GitHubPat",
        '--label org.opencontainers.image.title=AzCliCredentialProxy'
        '--label org.opencontainers.image.description='
        '--label org.opencontainers.image.url=https://github.com/ClassonConsultingAB/AzCliCredentialProxy'
        '--label org.opencontainers.image.source=https://github.com/ClassonConsultingAB/AzCliCredentialProxy'
        "--label org.opencontainers.image.version=$containerImageVersion"
        "--label org.opencontainers.image.created=$([DateTime]::UtcNow.ToString('o'))"
        "--label org.opencontainers.image.revision=$sha"
        '--label org.opencontainers.image.licenses=MIT'
        "-t $imageWithTag"
    )
    Exec "docker build $($build_args -join ' ') $root"
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
