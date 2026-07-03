FROM mcr.microsoft.com/dotnet/runtime-deps:10.0-alpine AS base
RUN apk add py3-pip && \
    pip install --break-system-packages azure-cli
ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    AZ_INSTALLER=DOCKER \
    AZURE_CONFIG_DIR=/app/.azure

FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS publish
ARG GITHUB_SOURCE_URL=https://nuget.pkg.github.com/ClassonConsultingAB/index.json
WORKDIR /src
RUN --mount=type=secret,id=github_token \
    dotnet nuget add source \
        --username docker \
        --password "$(cat /run/secrets/github_token)" \
        --store-password-in-clear-text \
        --name github ${GITHUB_SOURCE_URL}
COPY ./src/Api/*.csproj .
RUN dotnet restore -r linux-musl-x64
COPY ./src/Api .
RUN dotnet publish ./Api.csproj -c Release -r linux-musl-x64 -o /app/publish --no-restore --self-contained

FROM base AS final
RUN adduser --disabled-password --home /app appuser && chown -R appuser /app
WORKDIR /app
USER appuser
COPY --from=publish /app/publish .
EXPOSE 8080
ENTRYPOINT ["./Api"]
