# ---- Build stage ----
FROM ghcr.io/cirruslabs/flutter:3.29.0 AS builder

WORKDIR /app

# Copy Flutter project
COPY pubspec.yaml pubspec.lock ./
COPY lib/ ./lib/
COPY web/ ./web/
COPY assets/ ./assets/

# Get dependencies
RUN flutter pub get

# Generate code (freezed, json_serializable, injectable)
RUN flutter pub run build_runner build --delete-conflicting-outputs

# Build for web
RUN flutter build web --release

# ---- Runtime stage ----
FROM nginx:alpine AS runtime

# Copy built web files
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1
