ARG FREESURFER_BUILD_IMAGE=ubuntu:22.04
ARG SCILPY_BASE_IMAGE=scilus/scilpy:2.3.0_cpu

# Create a stage to build the freesurfer image (only essential scripts).
FROM $FREESURFER_BUILD_IMAGE AS build_freesurfer

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install packages needed for build
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates \
      file \
      git \
      python3-pip python3-full \
      upx \
      wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG PYTHON_VERSION=3.10


RUN pip3 install gdown

# Fetch install script in docker.
RUN mkdir /install
COPY ./install_freesurfer.sh /install/
RUN ["chmod", "+x", "/install/install_freesurfer.sh"]
SHELL ["/bin/bash", "--login", "-c"]

ARG FREESURFER_URL=default

RUN /install/install_freesurfer.sh /opt --upx --url $FREESURFER_URL

# Download extra utils here (gdown is available in this stage).
RUN gdown 11jz439JuoSUBUld7_WLGMCCFz5Uj3HgY -O /FS_BN_GL_SF_utils.tar

# Main stage from scilpy base image.
FROM $SCILPY_BASE_IMAGE AS runtime

ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages for freesurfer to dry_run
RUN apt-get update && apt-get install -y --no-install-recommends \
      bc \
      gawk \
      libgomp1 \
      libquadmath0 \
      libglu1-mesa \
      libxt6 \
      libxmu6 \
      libgl1 \
      freeglut3-dev \
      python3.10 \
      wget \
      curl \
      time \
      parallel \
      tcsh \
      python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add FreeSurfer and python Environment variables
# DO_NOT_SEARCH_FS_LICENSE_IN_FREESURFER_HOME=true deactivates the search for FS_LICENSE in FREESURFER_HOME
# Declared so the build linter knows PYTHONPATH (keeps the base image value if it sets one).
ARG PYTHONPATH
ENV OS=Linux \
    FS_OVERRIDE=0 \
    FIX_VERTEX_AREA="" \
    SUBJECTS_DIR=/opt/freesurfer/subjects \
    FSF_OUTPUT_FORMAT=nii.gz \
    FREESURFER_HOME=/opt/freesurfer \
    PYTHONUNBUFFERED=1 \
    PATH=/venv/bin:/opt/freesurfer/bin:$PATH \
    PYTHONPATH=/opt/freesurfer/python/packages${PYTHONPATH:+:$PYTHONPATH} \
    MPLCONFIGDIR=/tmp/matplotlib-config \
    DO_NOT_SEARCH_FS_LICENSE_IN_FREESURFER_HOME="true"

COPY --from=build_freesurfer /opt/freesurfer /opt/freesurfer

RUN wget -O /opt/freesurfer/.license "https://www.dropbox.com/s/zs4k3bcfxderj58/license.txt?dl=0"

COPY --from=build_freesurfer /FS_BN_GL_SF_utils.tar /FS_BN_GL_SF_utils.tar
# The archive carries mode 700 + a host uid; normalize so files copied out by
# processes (running as root) stay readable by the host user during unstaging.
RUN tar xf /FS_BN_GL_SF_utils.tar -C / --no-same-owner --no-same-permissions && \
    chmod -R a+rX,go-w /FS_BN_GL_SF_utils && \
    rm /FS_BN_GL_SF_utils.tar