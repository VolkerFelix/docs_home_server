# Installation with docker compose

We provide a configuration for running Docs in production using docker compose. This configuration is experimental, the official way to deploy Docs in production is to use [k8s](docs/installation/k8s.md)

## Requirements

- A modern version of Docker and its Compose plugin
- A domain name or subdomain (e.g., areum-hub.duckdns.org)
- UFW firewall (or similar) for securing access
- Let's Encrypt for SSL certificates

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/VolkerFelix/docs_home_server.git
   cd docs
   ```

2. Set up SSL certificates using Let's Encrypt:
   ```bash
   sudo apt install certbot
   sudo certbot certonly --standalone -d your-domain.com
   ```
   The certificates will be stored in `/etc/letsencrypt/live/your-domain.com/`

3. Configure firewall rules:
   ```bash
   sudo ufw allow 8443/tcp  # Keycloak
   sudo ufw allow 8444/tcp  # Main application
   ```

4. Initialize the production environment:
   ```bash
   make bootstrap-production
   ```

## Configuration

### SSL Certificates Configuration

The SSL certificates from Let's Encrypt are automatically mounted in the containers:

1. For the main application (nginx):
   - Certificates are mounted at `/etc/nginx/ssl` in the ingress container
   - Used in `docker/files/production/etc/nginx/conf.d/default.conf`

2. For Keycloak:
   - Certificates are mounted at `/etc/ssl/certs` in the Keycloak container
   - The paths are configured in the compose file

### Environment Files Configuration

1. `env.d/production/minio`:
   ```env
   MINIO_ROOT_USER=<YOUR_MINIO_ACCESS_KEY>
   MINIO_ROOT_PASSWORD=<YOUR_MINIO_SECRET_KEY>
   ```

2. `env.d/production/postgresql`:
   ```env
   POSTGRES_DB=docs
   POSTGRES_USER=docs
   POSTGRES_PASSWORD=<YOUR_DB_PASSWORD>
   ```

3. `env.d/production/yprovider`:
   ```env
   Y_PROVIDER_SECRET_KEY=<YOUR_Y_PROVIDER_SECRET_KEY>
   Y_PROVIDER_ALLOWED_HOSTS=your-domain.com
   Y_PROVIDER_DEBUG=False
   Y_PROVIDER_REDIS_URL=redis://redis:6379/0
   Y_PROVIDER_CORS_ORIGINS=https://your-domain.com:8444
   COLLABORATION_LOGGING=true
   COLLABORATION_API_URL=https://your-domain.com:8444/collaboration/api/
   COLLABORATION_SERVER_ORIGIN=https://your-domain.com:8444
   COLLABORATION_SERVER_ORIGIN_ALLOWED=true
   COLLABORATION_SERVER_SECRET=<YOUR_COLLABORATION_SERVER_SECRET>
   Y_PROVIDER_API_KEY=<YOUR_Y_PROVIDER_API_KEY>
   ```

4. `env.d/production/kc_postgresql`:
   ```env
   POSTGRES_DB=keycloak
   POSTGRES_USER=keycloak
   POSTGRES_PASSWORD=<YOUR_KEYCLOAK_DB_PASSWORD>
   ```

5. `env.d/production/keycloak`:
   ```env
   KEYCLOAK_ADMIN=<YOUR_KEYCLOAK_ADMIN_USER>
   KEYCLOAK_ADMIN_PASSWORD=<YOUR_KEYCLOAK_ADMIN_PASSWORD>
   KC_DB=postgres
   KC_DB_URL=jdbc:postgresql://kc_postgresql:5432/keycloak
   KC_DB_USERNAME=keycloak
   KC_DB_PASSWORD=<YOUR_KEYCLOAK_DB_PASSWORD>
   KC_HOSTNAME=your-domain.com
   KC_HOSTNAME_STRICT=false
   KC_HOSTNAME_STRICT_HTTPS=false
   KC_HTTP_ENABLED=true
   KC_PROXY=edge
   ```

6. `env.d/production/backend`:
   Configure all Django and OIDC settings. Important settings include:
   ```env
   DJANGO_SECRET_KEY=<YOUR_DJANGO_SECRET_KEY>
   DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com
   DJANGO_DATABASE_URL=postgres://docs:<YOUR_DB_PASSWORD>@postgresql:5432/docs
   DJANGO_MEDIA_ACCESS_KEY=<YOUR_MINIO_ACCESS_KEY>
   DJANGO_MEDIA_SECRET_KEY=<YOUR_MINIO_SECRET_KEY>
   ```

### Generating Secure Keys

For all placeholder values (marked with `<YOUR_*>`), generate secure random keys:
```bash
# Generate a secure random key
openssl rand -base64 32
```

## Keycloak Configuration

1. Start the services:
   ```bash
   make deploy
   ```

2. Access Keycloak admin interface at `https://your-domain.com:8443`
   - Log in with the admin credentials set in `env.d/production/keycloak`


3. Create a new client:
   - Go to "Clients" → "Create"
   - Set Client ID to "docs"
   - Enable "Client authentication"
   - Set Valid redirect URIs to `https://your-domain.com:8444/*`
   - Save the client

4. Get the client secret:
   - Go to the "Credentials" tab of your client
   - Copy the client secret
   - Update `OIDC_RP_CLIENT_SECRET` in `env.d/production/backend`

5. Configure user attributes:
   - In the realm settings, go to "Client Scopes" → "roles" → "Mappers"
   - Add mappers for "given_name" and "usual_name"

6. Restart the services:
   ```bash
   make clean-production
   make deploy
   ```

## Running the Application

1. Start all services:
   ```bash
   make deploy
   ```

2. Monitor the services:
   ```bash
   COMPOSE_FILE=compose.production.yaml ./bin/compose ps
   ```

3. Access the application:
   - Main application: `https://your-domain.com:8444`
   - Keycloak admin: `https://your-domain.com:8443`

## Backup

Important directories to backup:
- `data/production/databases/backend/` - Contains the main application database
- `data/production/databases/keycloak/` - Contains the Keycloak database
- `data/production/media/` - Contains uploaded files and media
- `env.d/production/` - Contains all configuration files
- `/etc/letsencrypt/` - Contains SSL certificates

## Troubleshooting

1. Check logs for specific services:
   ```bash
   COMPOSE_FILE=compose.production.yaml ./bin/compose logs -f service_name
   ```

2. Common issues:
   - If user collaboration doesn't work, check Y-provider logs and CORS settings
   - If authentication fails, verify Keycloak client settings and secrets
   - For SSL issues, ensure certificates are properly mounted and configured
