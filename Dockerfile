FROM debian:13-slim

# --- Dépendances de build ComplianceAsCode/content ---
# openscap-scanner fournit la bibliothèque OpenSCAP sur Debian 13.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    make \
    python3 \
    python3-pip \
    python3-yaml \
    python3-jinja2 \
    libxml2-utils \
    xsltproc \
    openscap-utils \
    openscap-scanner \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# --- Récupération des sources upstream ---
# TARGET_REF : tag/branche à cloner (par défaut master).
ARG TARGET_REF=master
RUN git clone --depth 1 --branch ${TARGET_REF} \
    https://github.com/ComplianceAsCode/content.git content \
    || git clone --depth 50 https://github.com/ComplianceAsCode/content.git content

WORKDIR /build/content
RUN pip3 install --break-system-packages -r requirements.txt

# --- Script qui porte les profils ANSSI vers le produit ciblé ---
COPY port-anssi.sh /build/port-anssi.sh
RUN chmod +x /build/port-anssi.sh

# --- Produits source et cible. Modifiables au build ou au run. ---
ARG SOURCE_PRODUCT=debian13
ARG TARGET_PRODUCT
ENV SOURCE_PRODUCT=${SOURCE_PRODUCT}
ENV TARGET_PRODUCT=${TARGET_PRODUCT}

VOLUME ["/build/content/build"]

ENTRYPOINT ["/build/port-anssi.sh"]
CMD ["build"]
