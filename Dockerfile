FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY eShopOnWeb/eShopOnWeb.sln ./
COPY eShopOnWeb/src/ApplicationCore/*.csproj src/ApplicationCore/
COPY eShopOnWeb/src/BlazorAdmin/*.csproj src/BlazorAdmin/
COPY eShopOnWeb/src/BlazorShared/*.csproj src/BlazorShared/
COPY eShopOnWeb/src/Infrastructure/*.csproj src/Infrastructure/
COPY eShopOnWeb/src/PublicApi/*.csproj src/PublicApi/
COPY eShopOnWeb/src/Web/*.csproj src/Web/

RUN dotnet restore

COPY eShopOnWeb/src/ src/

WORKDIR /src/src/Web
RUN dotnet publish -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

RUN adduser --disabled-password --gecos '' appuser && chown -R appuser /app
USER appuser

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

ENTRYPOINT ["dotnet", "Web.dll"]
