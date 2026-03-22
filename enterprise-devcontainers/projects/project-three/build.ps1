# Build, tag, and push the Tier 3 Project Three image.
# Usage: .\build.ps1 [-Registry <registry>]
param(
    [string]$Registry = "kapconreg.azurecr.io/devcontainers"
)
$ErrorActionPreference = "Stop"

$Image = "$Registry/project-three:latest"

# Authenticate with ACR
az acr login --name kapconreg
if ($LASTEXITCODE -ne 0) { throw "ACR login failed" }

Write-Host "--- Building project-three ---"
docker build -t $Image .
if ($LASTEXITCODE -ne 0) { throw "Docker build failed" }

Write-Host "--- Scanning $Image for vulnerabilities ---"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --exit-code 1 --severity CRITICAL $Image
if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARN] Trivy found CRITICAL vulnerabilities. Review before pushing." -ForegroundColor Yellow
    # To block push on critical CVEs, uncomment: throw "Trivy scan failed"
}

Write-Host "--- Pushing $Image ---"
docker push $Image
if ($LASTEXITCODE -ne 0) { throw "Docker push failed" }

Write-Host "Done: $Image"
