# Container Usage Guide

## Overview

The Monero Rental Hash War repository supports multiple container runtimes:

- **macOS**: `container` CLI (Apple's native container runtime)
- **Linux/Other**: `podman` (Docker-compatible, daemonless)
- **Fallback**: `docker` (if available)

The `justfile` automatically detects and uses the appropriate runtime.

## Prerequisites

### macOS Container CLI

On macOS with Container CLI installed:
```bash
# Verify installation
container --version
```

### Podman (Linux/BSD/Windows)

```bash
# Install podman
# Fedora/RHEL
sudo dnf install podman

# Ubuntu/Debian
sudo apt install podman

# Arch
sudo pacman -S podman

# macOS (via Homebrew, as fallback)
brew install podman

# Verify
podman --version
```

### Docker (Fallback)

```bash
# Install via Docker Desktop or package manager
docker --version
```

## Quick Start

### Check Available Runtime

```bash
just container-info
```

Output:
```
Container runtime: container
Apple Container v1.0
```

### Build Image

```bash
just container-build
```

This detects your runtime and builds with appropriate flags.

### Run Analysis

```bash
just container-run
```

Output shows the full OpenGame equilibrium analysis.

## Container Recipes

### 1. Basic Analysis Run

```bash
just container-run
```

Runs `MoneroRentalHashWarStandalone.hs` inside container with full output.

### 2. Live Network Monitoring

```bash
just container-watch
```

Starts continuous monitoring with 60-second intervals:
```
👁️  Watching Jetski Pool data (updates every 60s)
   Press Ctrl+C to stop

[2025-10-05 13:45:30]
  Network: 4.97 GH/s
  Qubic: 0.75 GH/s (15.1%)
  Orphans (24h): 0
  Withholding score: 0.08
  XMR: $320.69
  🟢 LOW THREAT
```

### 3. Interactive Shell

```bash
just container-shell
```

Opens bash shell inside container:
```bash
root@abc123:/app# runghc src/MoneroRentalHashWarStandalone.hs
root@abc123:/app# python3 scripts/jetski_tracker_integration.py
root@abc123:/app# ls -la src/
```

### 4. Development Mode (Volume Mounts)

```bash
just container-dev
```

Mounts local source directories into container for live editing:
- `src/` → `/app/src` (read-only)
- `scripts/` → `/app/scripts` (read-only)
- `examples/` → `/app/examples` (read-write)

Edit files locally, run in container without rebuild.

### 5. Clean Images

```bash
just container-clean
```

Removes built images to free space.

## Runtime Detection Logic

The justfile uses this detection hierarchy:

```bash
_container-runtime:
    if command -v container >/dev/null 2>&1; then
        echo "container"  # macOS Container CLI
    elif command -v podman >/dev/null 2>&1; then
        echo "podman"     # Podman (Linux/other)
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"     # Docker fallback
    else
        exit 1            # Error: no runtime found
    fi
```

**Priority:**
1. `container` (macOS native)
2. `podman` (preferred for non-macOS)
3. `docker` (fallback compatibility)

## Platform-Specific Notes

### macOS Container CLI

**Advantages:**
- Native Apple Silicon support
- No daemon required
- Integrates with macOS security
- Fast image building

**Usage:**
```bash
# Build
container build -t monero-rental-hash-war:latest .

# Run
container run --rm monero-rental-hash-war:latest

# Shell
container run --rm -it monero-rental-hash-war:latest bash
```

### Podman (Linux/BSD)

**Advantages:**
- Daemonless (rootless by default)
- Docker-compatible CLI
- Enhanced security (no root daemon)
- Kubernetes-compatible pods

**Usage:**
```bash
# Build
podman build -t monero-rental-hash-war:latest .

# Run
podman run --rm monero-rental-hash-war:latest

# Shell
podman run --rm -it monero-rental-hash-war:latest bash
```

**Rootless mode** (recommended):
```bash
# Run as non-root user
podman run --rm --user $(id -u):$(id -g) monero-rental-hash-war:latest
```

### Docker (Fallback)

**Usage:**
```bash
# Build
docker build -t monero-rental-hash-war:latest .

# Run
docker run --rm monero-rental-hash-war:latest

# Shell
docker run --rm -it monero-rental-hash-war:latest bash
```

## Container Image Details

### Base Image
- **Builder stage**: `haskell:9.6.3-slim`
- **Runtime stage**: `debian:bookworm-slim`

### Installed Components
- GHC 9.6.3 (Haskell compiler)
- Python 3.11+
- UV (Python package manager)
- curl, ca-certificates

### Environment Variables
- `MONERO_SEED=1069` (seed for reproducibility)
- `PATH` includes UV binary location

### Default Command
```dockerfile
CMD ["runghc", "src/MoneroRentalHashWarStandalone.hs"]
```

## Advanced Usage

### Custom Command

```bash
# Using container CLI (macOS)
container run --rm monero-rental-hash-war:latest \
    python3 scripts/jetski_tracker_integration.py --output /tmp/data.json

# Using podman (Linux)
podman run --rm monero-rental-hash-war:latest \
    runghc src/MoneroRentalHashWarWithLiveData.hs
```

### Port Forwarding (Future Web UI)

```bash
# Expose port 8080
RUNTIME=$(just _container-runtime)
$RUNTIME run --rm -p 8080:8080 monero-rental-hash-war:latest \
    python3 -m http.server 8080
```

### Volume Mounts for Data Persistence

```bash
RUNTIME=$(just _container-runtime)
$RUNTIME run --rm \
    -v "$(pwd)/examples:/app/examples" \
    monero-rental-hash-war:latest \
    python3 scripts/jetski_tracker_integration.py \
        --output /app/examples/container_data.json
```

### Multi-Architecture Builds

```bash
# Build for both AMD64 and ARM64
podman build --platform linux/amd64,linux/arm64 \
    -t monero-rental-hash-war:latest .

# Or with buildx (Docker)
docker buildx build --platform linux/amd64,linux/arm64 \
    -t monero-rental-hash-war:latest .
```

## Troubleshooting

### No Runtime Found

**Error:**
```
error: no container runtime found (install 'container' on macOS or 'podman' on other platforms)
```

**Solution:**
- **macOS**: Install Apple Container CLI
- **Linux**: `sudo apt install podman` or equivalent
- **Fallback**: Install Docker Desktop

### Permission Denied (Podman)

**Error:**
```
Error: cannot open file /var/lib/containers/storage/overlay: permission denied
```

**Solution:**
```bash
# Use rootless mode
podman system migrate
podman unshare chown -R $(id -u):$(id -g) ~/.local/share/containers
```

### Image Build Fails

**Error:**
```
ERROR: failed to solve: failed to fetch ...
```

**Solution:**
```bash
# Clean build cache
just container-clean

# Rebuild with no cache
RUNTIME=$(just _container-runtime)
$RUNTIME build --no-cache -t monero-rental-hash-war:latest .
```

### Volume Mount Issues (macOS Container CLI)

**Error:**
```
Error: volume mount not supported
```

**Solution:**
Use podman or docker for development mode with volumes:
```bash
# Install podman as fallback
brew install podman
podman machine init
podman machine start

# Now volume mounts work
just container-dev
```

## Performance Comparison

| Runtime | Build Time | Run Time | Memory | Notes |
|---------|-----------|----------|---------|-------|
| macOS Container | ~2 min | ~1.5s | ~50MB | Native ARM64, fastest |
| Podman (rootless) | ~3 min | ~2s | ~55MB | No daemon, secure |
| Docker | ~3 min | ~2s | ~60MB | Most compatible |

## CI/CD Integration

GitHub Actions example:
```yaml
jobs:
  container-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Podman
        run: sudo apt-get install -y podman
      - name: Build image
        run: just container-build
      - name: Run analysis
        run: just container-run
```

## Security Considerations

### Rootless Execution (Podman)

```bash
# Always run as non-root inside container
podman run --rm --user $(id -u):$(id -g) monero-rental-hash-war:latest
```

### Read-Only Filesystem

```bash
# Mount root filesystem as read-only
RUNTIME=$(just _container-runtime)
$RUNTIME run --rm --read-only monero-rental-hash-war:latest
```

### Network Isolation

```bash
# Disable network (for offline analysis)
RUNTIME=$(just _container-runtime)
$RUNTIME run --rm --network none monero-rental-hash-war:latest
```

## Summary

The unified container interface provides:
- ✅ **Cross-platform compatibility** - macOS, Linux, BSD, Windows
- ✅ **Automatic runtime detection** - Uses best available tool
- ✅ **Consistent interface** - Same `just` commands everywhere
- ✅ **Security-first** - Prefers rootless runtimes
- ✅ **Development-friendly** - Volume mounts for live editing

**Recommended setup:**
- **macOS**: Use native `container` CLI
- **Linux**: Use `podman` (rootless)
- **Windows**: Use `podman` via WSL2
- **CI/CD**: Use `podman` for security

---

◇ ♢ ◈ **Universal container orchestration with platform-native optimization** ◈ ♢ ◇
