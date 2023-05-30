FROM mcr.microsoft.com/dotnet/runtime-deps:7.0-alpine AS base
RUN apk add --no-cache py3-pip && \
    apk add --no-cache --virtual=build gcc musl-dev python3-dev libffi-dev openssl-dev cargo make && \
    pip install --no-cache-dir azure-cli && \
    apk del --purge build

FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine AS publish
ARG GITHUB_SOURCE_PASSWORD
ARG GITHUB_SOURCE_URL=https://nuget.pkg.github.com/ClassonConsultingAB/index.json
WORKDIR /src
RUN dotnet nuget add source --username docker --password ${GITHUB_SOURCE_PASSWORD} --store-password-in-clear-text --name github ${GITHUB_SOURCE_URL}
COPY ./src/Api/*.csproj .
RUN dotnet restore -r linux-musl-x64
COPY ./src/Api .
RUN dotnet build ./Api.csproj -c Release -r linux-musl-x64 --no-restore --self-contained
RUN dotnet publish ./Api.csproj -c Release -r linux-musl-x64 -o /app/publish --no-build

FROM base AS final
WORKDIR /app
RUN adduser --disabled-password --home /app --gecos '' app && chown -R app /app
USER app
COPY --chown=app --from=publish /app/publish .
ENV DOTNET_CLI_TELEMETRY_OPTOUT=true \
    AZ_INSTALLER=DOCKER \
    ASPNETCORE_URLS=http://+:80 \
    AZURE_CONFIG_DIR=/app/.azure
EXPOSE 80
ENTRYPOINT ["./Api"]
