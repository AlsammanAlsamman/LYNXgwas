#!/bin/sh
# Container entry point: prepare the workspace (/work) the way python/lynxgwas/cli.py does, then start the server
# in it. The workspace is the working directory; the application and its bin/ stay in /app.
set -e
W="${WORKSPACE:-/work}"
mkdir -p "$W"
for f in index.html viewer.html gene_constellation.html serpent_plot.html summary.html; do
  cp -f "/app/$f" "$W/$f"
done
for d in assets docs/images tools regulatory_links; do
  if [ -d "/app/$d" ]; then mkdir -p "$W/$d" && cp -rf "/app/$d/." "$W/$d/"; fi
done
CP="/app/bin"
for j in /app/lib/*.jar; do [ -e "$j" ] && CP="$CP:$j"; done
cd "$W"
exec java -Xmx"${LYNXGWAS_XMX:-8g}" -cp "$CP" Main "$@"
