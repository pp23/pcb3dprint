FROM ubuntu:24.04

ARG UVTOOLS_VERSION=7.1.0

ENV DEBIAN_FRONTEND=noninteractive \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# libgeotiff5 and libatlas3-base live in universe.
RUN sed -i '/^Components:/ { /universe/! s/$/ universe/ }' \
      /etc/apt/sources.list.d/ubuntu.sources \
 && apt-get update \
 && apt-get install --yes --no-install-recommends \
      ca-certificates \
      wget \
      libicu74 \
      libtiff6 \
      libgeotiff5 \
      libopenjp2-7 \
      libgstreamer1.0-0 \
      libgstreamer-plugins-base1.0-0 \
      libavcodec60 \
      libavformat60 \
      libavutil58 \
      libswscale7 \
      libgtk-3-0t64 \
      liblapack3 \
      libblas3 \
      libatlas3-base \
 && wget -O /tmp/uvtools.deb \
      "https://github.com/sn4k3/UVtools/releases/download/v${UVTOOLS_VERSION}/UVtools_linux-x64_v${UVTOOLS_VERSION}.deb" \
 && apt-get install --yes /tmp/uvtools.deb \
 && ln -sf /usr/lib/uvtools/UVtoolsCmd /usr/local/bin/UVtoolsCmd \
 && ! ldd /usr/lib/uvtools/libcvextern.so | grep -q 'not found' \
 && rm -rf /var/lib/apt/lists/* /tmp/uvtools.deb

WORKDIR /work
ENTRYPOINT ["UVtoolsCmd"]
