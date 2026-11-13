# ==========================================
# Stage 1: Build the Application
# ==========================================
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependency manifests first to leverage Docker layer caching
COPY package*.json ./

# Install all dependencies (including devDependencies needed for the Vite build)
RUN npm ci

# Copy the rest of the application source code
COPY . .

# Build the optimized production static files into the /app/dist folder
RUN npm run build


# ==========================================
# Stage 2: Serve with Nginx (Production)
# ==========================================
FROM nginx:alpine AS runner

# Copy the production build output from the builder stage to Nginx's public folder
COPY --from=builder /app/dist /usr/share/nginx/html

# Use a custom Nginx config so the SPA is served on port 5173 and /api routes
# are proxied to the Flask backend instead of falling through to static files.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose the same port used by docker-compose and Kubernetes manifests.
EXPOSE 5173

# Start Nginx in the foreground
CMD ["nginx", "-g", "daemon off;"]
