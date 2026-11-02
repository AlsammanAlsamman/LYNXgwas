# LYNXgwas desktop edition in a container, with the exact tool versions used for the article.
#
#   docker build -t lynxgwas .
#   docker run --rm -p 127.0.0.1:8765:8765 -v "$PWD/workspace:/work" lynxgwas
#   docker run --rm -p 127.0.0.1:8765:8765 -v "$PWD/workspace:/work" lynxgwas --offline   # no outgoing requests
#
# Versions (as used for the 30-dataset evaluation):
#   R 4.6.1; susieR 0.14.2 (single-dataset SuSiE); bigsnpr 1.12.21; bigstatsr 1.6.2; data.table 1.18.4;
#   Matrix 1.7.6; coloc 5.2.3; RSpectra 0.16.2; jsonlite 2.0.0
#   joint fine-mapping library (LYNXGWAS_R_LIB): susieR 0.16.6 (stephenslab/susieR@8e56a8e) and
#   mvsusieR 0.3.0 (stephenslab/mvsusieR@8edc67a), kept apart because mvsusieR needs susieR >= 0.15.54
#   PLINK 1.9.0-b.7.11 (19 Aug 2025); GCTA 1.94.1; MAGMA 1.10; GWAMA 2.2.2; Java 17
#
# The image has not been built yet (no Docker on the machine it was written on). The four download URLs below were
# checked on 2 November 2026: each returns the expected archive or binary (MAGMA: the Linux v1.10 build). GCTA comes
# from its GitHub release, because the publisher's site serves a JavaScript check instead of the file.

FROM rocker/r-ver:4.6.1

ARG PLINK_URL=https://s3.amazonaws.com/plink1-assets/plink_linux_x86_64_20250819.zip
ARG GCTA_URL=https://github.com/jianyangqt/gcta/releases/download/v1.94.1/gcta-1.94.1-linux-x86_64-static
ARG MAGMA_URL=https://vu.data.surfsara.nl/index.php/s/zkKbNeNOZAhFXZB/download
ARG GWAMA_URL=https://www.geenivaramu.ee/tools/GWAMA_v2.2.2.zip

RUN apt-get update && apt-get install -y --no-install-recommends \
        openjdk-17-jdk-headless unzip curl ca-certificates build-essential zlib1g-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev python3 \
    && rm -rf /var/lib/apt/lists/*

# ── external programs, on PATH (ToolLocator looks in bin/ first, then PATH) ──
RUN mkdir -p /opt/tools /tmp/dl && cd /tmp/dl \
    && curl -fsSL -o plink.zip "$PLINK_URL" && unzip -q plink.zip plink -d /opt/tools \
    && curl -fsSL -o /opt/tools/gcta64 "$GCTA_URL" \
    && curl -fsSL -o magma.zip "$MAGMA_URL" && unzip -q magma.zip && find . -name magma -type f -exec cp {} /opt/tools/ \; \
    && curl -fsSL -o gwama.zip "$GWAMA_URL" && unzip -q gwama.zip -d gwama && make -C "$(dirname "$(find gwama -name Makefile | head -1)")" \
    && find gwama -name GWAMA -type f -exec cp {} /opt/tools/ \; \
    && chmod +x /opt/tools/* && rm -rf /tmp/dl
ENV PATH="/opt/tools:${PATH}"

# ── R packages, pinned ──
RUN R -q -e 'install.packages("remotes")' \
    && R -q -e 'v <- c(susieR="0.14.2", bigstatsr="1.6.2", bigsnpr="1.12.21", data.table="1.18.4", Matrix="1.7.6", \
                       coloc="5.2.3", RSpectra="0.16.2", jsonlite="2.0.0"); \
                for (p in names(v)) remotes::install_version(p, v[[p]], upgrade = "never"); \
                stopifnot(all(sapply(names(v), function(p) as.character(packageVersion(p)) == v[[p]])))'
ENV LYNXGWAS_R_LIB=/opt/mvsusie-lib
RUN mkdir -p "$LYNXGWAS_R_LIB" \
    && R -q -e 'lib <- Sys.getenv("LYNXGWAS_R_LIB"); \
                remotes::install_github("stephenslab/susieR@8e56a8e038e989856d106d9ca5175cc664fea9d2", lib = lib, upgrade = "never"); \
                remotes::install_github("stephenslab/mvsusieR@8edc67afa11cfcfc7e057595da96db40962cdd7f", lib = lib, upgrade = "never"); \
                stopifnot(packageVersion("mvsusieR", lib.loc = lib) == "0.3.0")'

# ── the application ──
WORKDIR /app
COPY . /app
RUN sh build.sh && sh run_tests.sh

# Inside the container the server must listen on all interfaces for Docker to forward the port; publish it on the
# host's loopback only (-p 127.0.0.1:8765:8765) so the desktop edition stays reachable from this computer alone.
ENV LYNXGWAS_BIND=0.0.0.0
EXPOSE 8765
VOLUME ["/work"]
ENTRYPOINT ["sh", "/app/docker-entrypoint.sh"]
