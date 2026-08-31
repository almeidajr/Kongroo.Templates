FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish src/Kongroo.SampleApp.Worker/Kongroo.SampleApp.Worker.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/runtime:10.0 AS final
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
ENTRYPOINT ["dotnet", "Kongroo.SampleApp.Worker.dll"]
