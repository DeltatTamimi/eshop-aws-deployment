FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

COPY eShopOnWeb/ ./

RUN dotnet restore src/Web/Web.csproj
RUN dotnet publish src/Web/Web.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Docker
ENV UseOnlyInMemoryDatabase=true

ENTRYPOINT ["dotnet", "Web.dll"]