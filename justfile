# Monero Rental Hash War - Just commands

# Default recipe
default:
    @just --list

# Run standalone OpenGame analysis
run:
    runghc src/MoneroRentalHashWarStandalone.hs

# Fetch live network data
fetch-live:
    uvx --from requests python3 scripts/jetski_tracker_integration.py --output examples/jetski_live_data.json

# Continuous monitoring (60s intervals)
watch:
    uvx --from requests python3 scripts/jetski_tracker_integration.py --watch --interval 60

# Run with live data integration (requires opengames-engine)
run-live:
    runghc src/MoneroRentalHashWarWithLiveData.hs

# Compile to native binary (requires compatible LLVM)
compile:
    ghc --make src/MoneroRentalHashWarStandalone.hs -o bin/monero_game

# Clean build artifacts
clean:
    rm -f src/*.hi src/*.o bin/*

# Generate Haskell format from live data
fetch-haskell:
    uvx --from requests python3 scripts/jetski_tracker_integration.py --output examples/jetski_data.hs --haskell

# Run all examples
examples:
    @echo "═══ Standalone Analysis ═══"
    runghc src/MoneroRentalHashWarStandalone.hs | head -50
    @echo ""
    @echo "═══ Live Network Data ═══"
    uvx --from requests python3 scripts/jetski_tracker_integration.py

# Check GHC and LLVM versions
check-deps:
    @echo "GHC version:"
    @ghc --version
    @echo ""
    @echo "LLVM version (if installed):"
    @opt --version 2>/dev/null || echo "LLVM not in PATH"

# Verify seed 1069 in codebase
verify-seed:
    @echo "Checking seed 1069 occurrences:"
    @grep -n "1069" src/*.hs scripts/*.py | grep -v "^Binary"

# Run with debug output
debug:
    @echo "Running with trace output..."
    runghc -ddump-simpl src/MoneroRentalHashWarStandalone.hs 2>&1 | less

# Format Haskell code (requires stylish-haskell)
format:
    find src -name "*.hs" -exec stylish-haskell -i {} \;

# Lint Haskell code (requires hlint)
lint:
    hlint src/

# Generate documentation (requires haddock)
docs:
    haddock --html --odir=docs/api src/*.hs

# Performance profiling (requires GHC profiling build)
profile:
    ghc -prof -fprof-auto -rtsopts src/MoneroRentalHashWarStandalone.hs -o bin/monero_game_prof
    ./bin/monero_game_prof +RTS -p
    cat MoneroRentalHashWarStandalone.prof

# Package for distribution
package: clean
    tar czf monero-rental-hash-war.tar.gz \
        src/ scripts/ docs/ examples/ README.md justfile

# Initialize git repository
init-git:
    git init
    git add .
    git commit -m "Initial commit: Monero Rental Hash War OpenGame"

# Push to GitHub
push-github:
    gh repo create monero-rental-hash-war --private --source=. --remote=origin
    git push -u origin main

# Detect container runtime (macOS Container or podman)
_container-runtime:
    #!/usr/bin/env bash
    if command -v container >/dev/null 2>&1; then
        echo "container"
    elif command -v podman >/dev/null 2>&1; then
        echo "podman"
    elif command -v docker >/dev/null 2>&1; then
        echo "docker"
    else
        echo "error: no container runtime found (install 'container' on macOS or 'podman' on other platforms)" >&2
        exit 1
    fi

# Build container image
container-build:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Building with $RUNTIME..."
    $RUNTIME build -t monero-rental-hash-war:latest .

# Run analysis in container
container-run:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Running OpenGame analysis in $RUNTIME container..."
    $RUNTIME run --rm monero-rental-hash-war:latest

# Run with live data fetch in container
container-watch:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Starting live monitoring in $RUNTIME container..."
    $RUNTIME run --rm -it monero-rental-hash-war:latest \
        bash -c "uvx --from requests python3 scripts/jetski_tracker_integration.py --watch --interval 60"

# Interactive shell in container
container-shell:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Opening shell in $RUNTIME container..."
    $RUNTIME run --rm -it monero-rental-hash-war:latest bash

# Run container with volume mount for live development
container-dev:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Running development container with $RUNTIME..."
    $RUNTIME run --rm -it \
        -v "$(pwd)/src:/app/src:ro" \
        -v "$(pwd)/scripts:/app/scripts:ro" \
        -v "$(pwd)/examples:/app/examples" \
        monero-rental-hash-war:latest bash

# Clean container images
container-clean:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Cleaning $RUNTIME images..."
    $RUNTIME rmi monero-rental-hash-war:latest || true

# Check container runtime and version
container-info:
    #!/usr/bin/env bash
    RUNTIME=$(just _container-runtime)
    echo "Container runtime: $RUNTIME"
    $RUNTIME --version
