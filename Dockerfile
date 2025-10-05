FROM haskell:9.6.3-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy source files
COPY src/ src/
COPY scripts/ scripts/

# Build standalone (no cabal needed - uses runghc)
RUN ghc --version

# Runtime stage
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ghc \
    python3 \
    python3-pip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install UV for Python management
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:${PATH}"

# Copy source and scripts
COPY --from=builder /app/src/ /app/src/
COPY --from=builder /app/scripts/ /app/scripts/
COPY examples/ /app/examples/
COPY docs/ /app/docs/

WORKDIR /app

# Set seed 1069 as environment variable
ENV MONERO_SEED=1069

# Default command runs the standalone analysis
CMD ["runghc", "src/MoneroRentalHashWarStandalone.hs"]

# Labels
LABEL org.opencontainers.image.title="Monero Rental Hash War"
LABEL org.opencontainers.image.description="Compositional OpenGame analysis with live network integration"
LABEL org.opencontainers.image.authors="bmorphism"
LABEL org.opencontainers.image.source="https://github.com/bmorphism/monero-rental-hash-war"
