# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       build-essential \
       autoconf \
       automake \
       libtool \
       pkg-config \
       libevent-dev \
       libjansson-dev \
       libssl-dev \
       libcurl4-openssl-dev \
       uthash-dev \
       dos2unix \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# ตรงนี้สมมติว่าโฟลเดอร์ ckpool ทั้งชุดอยู่ใน src/ ของ context
# (ตามโครงที่เคยส่งมา)
COPY src/ /src

RUN if [ ! -f /src/autogen.sh ]; then \
        echo "ckpool sources are missing. Run ./ckpool/fetch-source.sh before building." >&2; \
        exit 1; \
    fi && \
    rm -f /src/.gitkeep && rm -rf /src/.git

# 🔧 FIX หลัก: แปลง CRLF -> LF ในไฟล์ autotools ทั้งหมดก่อนรัน autogen
RUN mkdir -p m4 \
    && find . -type f \( -name '*.m4' -o -name '*.ac' -o -name '*.am' -o -name '*.sh' \) -exec dos2unix {} + \
    && chmod +x autogen.sh \
    && ./autogen.sh \
    && ./configure \
    && make -j"$(nproc)"

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       bash \
       libevent-2.1-7 \
       libjansson4 \
       libssl3 \
       libcurl4 \
    && rm -rf /var/lib/apt/lists/*

# ckpool's autotools tree outputs the binary under src/ckpool relative to the
# repository root, so grab that path from the builder stage.
COPY --from=builder /src/src/ckpool /usr/local/bin/ckpool
COPY run-ckpool.sh /usr/local/bin/run-ckpool
RUN chmod +x /usr/local/bin/run-ckpool

ENTRYPOINT ["ckpool"]
CMD ["-h"]
