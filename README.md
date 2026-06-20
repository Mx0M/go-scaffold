# 🚀 go-scaffold

**Production Go Microservice Generator — Single File, Zero Dependencies**

Generate a complete, production-ready Go microservice in seconds. One bash script. No cloning. No templates. No setup.

```
    	   __  __      ___
    			|  \/  |_  _/ _ \ _ __ ___
    			| |\/| \ \/ / | | | '_ ` _ \
    			| |  | |>  <| |_| | | | | | |
    			|_|  |_/_/\_\\___/|_| |_| |_|


        Production Go Microservice Generator  v1.0.2
```

---

## ✨ What It Does

`go-scaffold` is a **single bash script** that generates an entire Go microservice project from scratch. It asks you a few questions (or takes flags), then creates a fully working, production-grade codebase with:

- 🧱 Clean architecture (handler → service → repository)
- 🔐 JWT authentication with bcrypt password hashing
- 🗄️ Multi-database support (PostgreSQL, MySQL, MongoDB, Redis)
- 📝 Structured JSON logging (Zap)
- 🛡️ Middleware stack (CORS, rate limiting, request ID, panic recovery)
- 🐳 Docker + docker-compose (multi-stage builds)
- 🔄 Graceful shutdown with signal handling
- 🧪 Unit tests with repository mocking
- ⚙️ Smart config system (`.env` > YAML > defaults)

---

## 🎯 Why Use This?

| Problem | go-scaffold Solution |
|---------|---------------------|
| "I need to start a new Go service" | Run one script, get a full project |
| "Setting up clean architecture is tedious" | Done automatically |
| "I keep forgetting middleware patterns" | All included, battle-tested |
| "Docker setup is always a pain" | Multi-stage Dockerfile included |
| "Config management is confusing" | `.env` + YAML + ENV, priority handled |
| "I don't want to clone templates" | Single file, no clone needed |

---

## 🚀 Installation

### Option 1: Download Directly

```bash
curl -sSL https://raw.githubusercontent.com/mx0m/go-scaffold/main/go-scaffold.sh -o go-scaffold.sh
chmod +x go-scaffold.sh
```

### Option 2: Clone & Use

```bash
git clone https://github.com/mx0m/go-scaffold.git
cd go-scaffold
chmod +x go-scaffold.sh
```

### Option 3: Install Globally

```bash
sudo curl -sSL https://raw.githubusercontent.com/mx0m/go-scaffold/main/go-scaffold.sh \
  -o /usr/local/bin/go-scaffold
sudo chmod +x /usr/local/bin/go-scaffold

# Now use from anywhere:
go-scaffold -n myservice -y
```

---

## 📖 Usage

### Interactive Mode (Recommended for First Time)

```bash
./go-scaffold.sh
```

You'll be prompted:
```
? Project name [myservice]: billing-api
? Go module path [github.com/you/billing-api]: github.com/acme/billing-api
? Choose primary database:
  1) postgres  (default)
  2) mysql
  3) mongodb
Choice [1]: 1
? HTTP port [8080]: 9000

Configuration:
  Project : billing-api
  Module  : github.com/acme/billing-api
  Output  : ./billing-api
  DB      : postgres
  Port    : 9000

? Proceed? [Y/n]: y
```

### Non-Interactive Mode (CI/CD Friendly)

```bash
./go-scaffold.sh -n billing-api \
                 -m github.com/acme/billing-api \
                 -d postgres \
                 -p 9000 \
                 -y
```

### All Flags

```bash
./go-scaffold.sh [OPTIONS]

OPTIONS:
  -n, --name NAME         Project name (required in non-interactive)
  -m, --module MODULE     Go module path (e.g. github.com/acme/api)
  -d, --db DRIVER         postgres|mysql|mongo (default: postgres)
  -p, --port PORT         HTTP port (default: 8080)
  -o, --dir DIR           Output directory (default: ./<name>)
  -y, --yes               Skip confirmation prompt
  -h, --help              Show help
```

---

## 🎁 What Gets Generated

```
your-project/
├── cmd/server/main.go              # Entry point with graceful shutdown
├── internal/
│   ├── handler/                    # HTTP handlers (user, health)
│   ├── service/                    # Business logic + tests
│   ├── repository/                 # DB abstraction (interface-based)
│   ├── model/                      # Domain models + DTOs
│   ├── middleware/                 # Auth, CORS, rate limit, logger
│   ├── auth/                       # JWT manager
│   ├── router/                     # Route definitions
│   └── config/                     # YAML + .env + ENV loader
├── pkg/
│   ├── logger/                     # Structured Zap logger
│   ├── response/                   # Standardized JSON responses
│   └── utils/                      # Password hashing, validators
├── db/                             # Postgres/MySQL/Mongo/Redis adapters
├── configs/config.yaml             # Default YAML config
├── docker/Dockerfile               # Multi-stage production build
├── docker-compose.yml              # App + DB + Redis
├── go.mod                          # With YOUR module path
├── .env.example                    # All config variables documented
├── .gitignore
└── README.md
```

---

## 🧪 After Generation

```bash
# 1. Enter the project
cd your-project

# 2. Configure via .env
cp .env.example .env
# Edit .env with your values

# 3. Download dependencies
go mod tidy

# 4. Run locally
go run ./cmd/server

# OR run with Docker
docker-compose up --build
```

---

## ⚙️ Configuration System

The generated project supports **3 ways** to configure, with clear priority:

| Priority | Source | Example |
|----------|--------|---------|
| 🥇 Highest | System ENV vars | `export DB_PORT=5433` |
| 🥈 Medium | `.env` file | `DB_PORT=5433` in `.env` |
| 🥉 Low | `configs/config.yaml` | `db.port: 5433` |
| 🏁 Fallback | Built-in defaults | Code defaults |

### ENV Variable Mapping

| YAML Key | ENV Variable |
|----------|--------------|
| `app.port` | `APP_PORT` |
| `db.host` | `DB_HOST` |
| `db.port` | `DB_PORT` |
| `db.user` | `DB_USER` |
| `db.password` | `DB_PASSWORD` |
| `db.name` | `DB_NAME` |
| `redis.host` | `REDIS_HOST` |
| `auth.jwt_secret` | `JWT_SECRET` |
| `log.level` | `LOG_LEVEL` |

**Rule:** Dots become underscores, all uppercase.

---

## 🌐 Generated API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | ❌ | Health check |
| POST | `/api/v1/auth/register` | ❌ | Register new user |
| POST | `/api/v1/auth/login` | ❌ | Login |
| GET | `/api/v1/users` | ✅ | List users |
| GET | `/api/v1/users/:id` | ✅ | Get user by ID |
| DELETE | `/api/v1/users/:id` | ✅ | Delete user |

### Try It

```bash
# Health check
curl http://localhost:8080/health

# Register
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","name":"Alice","password":"password123"}'

# Login
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"alice@example.com","password":"password123"}'

# List users (protected)
curl http://localhost:8080/api/v1/users \
  -H "Authorization: Bearer <your-token>"
```

---

## 🏗️ Architecture of Generated Project

```
HTTP Request
    │
    ▼
┌─────────────────────────────────────────┐
│  Middleware (RequestID, Logger, CORS,   │
│  RateLimit, Recovery, Auth)             │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Handler  (HTTP only, validation)       │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Service  (business logic)              │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  Repository (interface, DB adapters)    │
└─────────────────────────────────────────┘
    │
    ▼
  Postgres / MySQL / Mongo / Redis
```

**Key principles:**
- ✅ No business logic in handlers
- ✅ Repository interface for easy mocking
- ✅ Service layer is DB-agnostic
- ✅ Clean dependency flow (outer → inner)

---

## 🛠️ Adding a New Feature

Follow this 5-step pattern:

1. **Model** → `internal/model/your_entity.go`
2. **Repository** → `internal/repository/your_repository.go` (interface + impl)
3. **Service** → `internal/service/your_service.go` (business logic)
4. **Handler** → `internal/handler/your_handler.go` (HTTP layer)
5. **Router** → Register in `internal/router/router.go`

---

## 🐳 Docker Support

The generated project includes:

- **Multi-stage Dockerfile** — Small production image (~15MB)
- **docker-compose.yml** — App + your chosen DB + Redis
- **Health checks** — All services monitored
- **Graceful shutdown** — Clean termination

```bash
# Build and run
docker-compose up --build

# Run in background
docker-compose up -d

# View logs
docker-compose logs -f app
```

---

## 🧪 Testing

```bash
# Run all tests
go test ./...

# Run with coverage
go test -cover ./...

# Run specific package
go test ./internal/service/...
```

The generated project includes:
- Unit tests for service layer
- Mock repository implementation
- Handler test examples

---

## 🎯 Use Cases

| Use Case | How go-scaffold Helps |
|----------|----------------------|
| **Startup MVP** | Ship a backend in minutes, not days |
| **Microservices** | Consistent architecture across all services |
| **Team onboarding** | New devs get a working project instantly |
| **Hackathons** | Skip boilerplate, focus on features |
| **Enterprise** | Standardized patterns across teams |
| **Learning** | Study production-grade Go patterns |

---

## 🔧 Requirements

- **Bash 4+** (macOS, Linux, WSL)
- **Go 1.22+** (for the generated project)
- **Docker** (optional, for containerized runs)
- **OpenSSL** (for JWT secret generation — optional)

---

## 📊 Comparison

| Feature | go-scaffold | Manual Setup | Other Generators |
|---------|-------------|--------------|------------------|
| Setup time | ~10 seconds | Hours | Minutes |
| Files to manage | 1 | Many | Many |
| Clone required | ❌ No | ❌ No | ✅ Yes |
| Clean architecture | ✅ | ⚠️ Varies | ⚠️ Varies |
| Multi-DB support | ✅ | ⚠️ Manual | ❌ Rare |
| JWT auth included | ✅ | ⚠️ Manual | ⚠️ Sometimes |
| Docker included | ✅ | ⚠️ Manual | ⚠️ Sometimes |
| Customizable | ✅ Fully | ✅ Fully | ⚠️ Limited |

---

## 🤝 Contributing

Contributions welcome! Ideas:

- [ ] Add more database drivers (SQLite, Cassandra)
- [ ] Add gRPC support
- [ ] Add OpenAPI/Swagger generation
- [ ] Add migration tooling
- [ ] Add more middleware (tracing, metrics)
- [ ] Add Helm charts for Kubernetes

---

## 📜 License

MIT — Use it, fork it, sell it, whatever you want.

---

## 🙏 Credits

Built with:
- [Gin](https://github.com/gin-gonic/gin) — HTTP framework
- [GORM](https://gorm.io/) — ORM
- [Zap](https://github.com/uber-go/zap) — Structured logging
- [Viper](https://github.com/spf13/viper) — Config management
- [godotenv](https://github.com/joho/godotenv) — .env loader

---

## 📞 Support

- 🐛 [Report bugs](https://github.com/mx0m/go-scaffold/issues)
- 💡 [Request features](https://github.com/mx0m/go-scaffold/issues)
- 💬 [Discussions](https://github.com/mx0m/go-scaffold/discussions)

---

**Made with ❤️ for Go developers who value their time.**

```bash
# Get started now:
curl -sSL https://raw.githubusercontent.com/mx0m/go-scaffold/main/go-scaffold.sh | bash
```
