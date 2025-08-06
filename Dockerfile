# See https://aka.ms/containerfastmode to understand how Visual Studio uses this Dockerfile to build your images for faster debugging.

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

# Use non-Alpine SDK for better compatibility and memory handling
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

# Set more conservative memory limits for the build process
ENV DOTNET_GCHeapHardLimit=0x20000000
ENV DOTNET_GCHeapHardLimitPercent=75
# Add additional environment variables to help with memory management
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
ENV DOTNET_RUNNING_IN_CONTAINER=true

COPY ["NuGet.config","./"]
COPY ["Fmr.Spark.SystemApi/Fmr.Spark.SystemApi.csproj", "Fmr.Spark.SystemApi/"]
COPY ["Fmr.Spark.InfoServer.Common/Fmr.Spark.InfoServer.Common.csproj", "Fmr.Spark.InfoServer.Common/"]

# Restore projects with memory-conscious settings
RUN dotnet restore "Fmr.Spark.InfoServer.Common/Fmr.Spark.InfoServer.Common.csproj" \
    --disable-parallel \
    --verbosity minimal \
    --no-cache

RUN dotnet restore "Fmr.Spark.SystemApi/Fmr.Spark.SystemApi.csproj" \
    --disable-parallel \
    --verbosity minimal \
    --no-cache

ARG CONFIGURATION=Release
COPY . .
WORKDIR /src

# Build with memory-conscious settings
RUN dotnet build "Fmr.Spark.SystemApi/Fmr.Spark.SystemApi.csproj" \
    -c ${CONFIGURATION} \
    -o /app/build \
    /m:1 \
    --no-restore \
    --verbosity minimal

FROM build AS publish
ARG CONFIGURATION=Release

# Publish with memory-conscious settings
RUN dotnet publish "Fmr.Spark.SystemApi/Fmr.Spark.SystemApi.csproj" \
    -c ${CONFIGURATION} \
    -o /app/publish \
    --no-build \
    --no-restore \
    --verbosity minimal

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Fmr.Spark.SystemApi.dll"]