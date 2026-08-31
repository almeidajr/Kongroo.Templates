# syntax=docker/dockerfile:1.20
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore in its own layer, invalidated only by a csproj or a build file — not by a source edit.
# --parents keeps each csproj at its own path, so a ProjectReference restores without extra COPY lines.
COPY --parents Directory.*.props nuget.config global.json **/*.csproj ./
RUN dotnet restore src/Kongroo.SampleApp.Worker/Kongroo.SampleApp.Worker.csproj

COPY . .
RUN dotnet publish src/Kongroo.SampleApp.Worker/Kongroo.SampleApp.Worker.csproj \
      -c Release -o /app --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS final
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
ENTRYPOINT ["dotnet", "Kongroo.SampleApp.Worker.dll"]
