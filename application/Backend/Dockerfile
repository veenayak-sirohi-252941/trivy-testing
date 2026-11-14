# Stage 1: build dependencies
FROM python:3.10-slim AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: runtime image
FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    ca-certificates \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

COPY --from=builder /install /usr/local
COPY . .

EXPOSE 5000

CMD ["python", "app.py"]

# | Aspect                     | Original (single-stage)  | Multi-stage                 |
# | -------------------------- | ------------------------ | --------------------------- |
# | Build tools in final image | ✅ gcc, libpq-dev present | ❌ Removed                |
# | Image size                 | Larger (~500MB+)         | Smaller (~300-350MB)        |
# | Security                   | More vulnerabilities     | Fewer attack vectors        |
# | Purpose                    | Everything in one image  | Build separate from runtime |