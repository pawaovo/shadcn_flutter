FROM ubuntu@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517
ENV DEBIAN_FRONTEND=noninteractive
# Install dependencies only after creating the resource-limited container.
ENV DEPOT_TOOLS_UPDATE=0 DEPOT_TOOLS_METRICS=0 CIPD_CACHE_DIR=/work/cipd-cache
WORKDIR /work
CMD ["sleep", "infinity"]
