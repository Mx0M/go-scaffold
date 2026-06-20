#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERR]${NC}   $*" >&2; }
step()  { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }
die() { err "$*"; exit 1; }

banner() {
  echo -e "${CYAN}${BOLD}"
  cat <<'BANNER'
			__  __      ___
			|  \/  |_  _/ _ \ _ __ ___
			| |\/| \ \/ / | | | '_ ` _ \
			| |  | |>  <| |_| | | | | | |
			|_|  |_/_/\_\\___/|_| |_| |_|

        Production Go Microservice Generator  v1.0.1
BANNER
  echo -e "${NC}"
}

usage() {
  cat <<USAGE
USAGE: $(basename "$0") [OPTIONS]

OPTIONS:
  -n, --name NAME         Project name
  -m, --module MODULE     Go module path
  -d, --db DRIVER         postgres|mysql|mongo (default: postgres)
  -p, --port PORT         HTTP port (default: 8080)
  -o, --dir DIR           Output directory
  -y, --yes               Skip confirmation
  -h, --help              Show help
USAGE
  exit 0
}

PROJECT_NAME=""; MODULE_PATH=""; DB_DRIVER="postgres"
APP_PORT="8080"; OUTPUT_DIR=""; AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name)    PROJECT_NAME="$2"; shift 2 ;;
    -m|--module)  MODULE_PATH="$2"; shift 2 ;;
    -d|--db)      DB_DRIVER="$2"; shift 2 ;;
    -p|--port)    APP_PORT="$2"; shift 2 ;;
    -o|--dir)     OUTPUT_DIR="$2"; shift 2 ;;
    -y|--yes)     AUTO_YES=true; shift ;;
    -h|--help)    usage ;;
    *) die "Unknown option: $1" ;;
  esac
done

prompt() {
  local varname="$1" pr="$2" default="$3" val
  if [[ -z "${!varname}" ]]; then
    if [[ -n "$default" ]]; then
      printf "${YELLOW}?${NC} %s [${GREEN}%s${NC}]: " "$pr" "$default"
    else
      printf "${YELLOW}?${NC} %s: " "$pr"
    fi
    read -r val
    if [[ -z "$val" && -n "$default" ]]; then
      val="$default"
    fi
    eval "$varname=\$val"
  fi
}

choose_db() {
  if [[ -z "$DB_DRIVER" || "$DB_DRIVER" == "postgres" ]]; then
    echo -e "${YELLOW}?${NC} Choose primary database:"
    echo "  1) postgres  (default)"
    echo "  2) mysql"
    echo "  3) mongodb"
    printf "Choice [1]: "
    read -r c
    case "${c:-1}" in
      1) DB_DRIVER="postgres" ;;
      2) DB_DRIVER="mysql" ;;
      3) DB_DRIVER="mongo" ;;
      *) DB_DRIVER="postgres" ;;
    esac
  fi
}

banner

if [[ "$AUTO_YES" == false ]]; then
  prompt PROJECT_NAME "Project name" "myservice"
  [[ -z "$MODULE_PATH" ]] && prompt MODULE_PATH "Go module path" "github.com/you/${PROJECT_NAME}"
  [[ "$DB_DRIVER" == "postgres" ]] && choose_db
  prompt APP_PORT "HTTP port" "8080"
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="./${PROJECT_NAME}"
else
  [[ -z "$PROJECT_NAME" ]] && die "--name is required"
  [[ -z "$MODULE_PATH" ]] && MODULE_PATH="github.com/you/${PROJECT_NAME}"
  [[ -z "$OUTPUT_DIR" ]] && OUTPUT_DIR="./${PROJECT_NAME}"
fi

[[ "$PROJECT_NAME" =~ ^[a-z][a-z0-9-]*$ ]] || die "Invalid project name"
[[ "$DB_DRIVER" =~ ^(postgres|mysql|mongo)$ ]] || die "Invalid DB driver"
[[ "$APP_PORT" =~ ^[0-9]+$ ]] || die "Invalid port"

JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || head -c 64 /dev/urandom | od -An -tx1 | tr -d ' \n')
DB_PORT=5432
case "$DB_DRIVER" in
  postgres) DB_PORT=5432 ;;
  mysql)    DB_PORT=3306 ;;
  mongo)    DB_PORT=27017 ;;
esac

if [[ "$AUTO_YES" == false ]]; then
  echo
  echo -e "${BOLD}Configuration:${NC}"
  echo -e "  Project : ${GREEN}${PROJECT_NAME}${NC}"
  echo -e "  Module  : ${GREEN}${MODULE_PATH}${NC}"
  echo -e "  Output  : ${GREEN}${OUTPUT_DIR}${NC}"
  echo -e "  DB      : ${GREEN}${DB_DRIVER}${NC}"
  echo -e "  Port    : ${GREEN}${APP_PORT}${NC}"
  echo
  printf "${YELLOW}?${NC} Proceed? [Y/n]: "
  read -r confirm
  [[ "${confirm,,}" == "n" ]] && { warn "Aborted."; exit 0; }
fi

if [[ -d "$OUTPUT_DIR" ]]; then
  warn "Directory '$OUTPUT_DIR' exists."
  printf "Overwrite? [y/N]: "
  read -r ow
  [[ "${ow,,}" != "y" ]] && die "Aborted."
  rm -rf "$OUTPUT_DIR"
fi

step "Creating directory structure"
ROOT="$OUTPUT_DIR"
mkdir -p "$ROOT"/{cmd/server,internal/{handler,service,repository,model,middleware,auth,router,config},pkg/{logger,response,utils},db,configs,docker}
ok "Directories created"

write_file() {
  local target="$1"; shift
  local path="$ROOT/$target"
  mkdir -p "$(dirname "$path")"
  printf '%s' "$*" > "$path"
  ok "wrote $target"
}

# ============================================================================
# go.mod
# ============================================================================
step "Generating go.mod"
write_file "go.mod" "module ${MODULE_PATH}

go 1.22

require (
	github.com/gin-contrib/cors v1.7.2
	github.com/gin-gonic/gin v1.10.0
	github.com/golang-jwt/jwt/v5 v5.2.1
	github.com/google/uuid v1.6.0
	github.com/joho/godotenv v1.5.1
	github.com/redis/go-redis/v9 v9.5.3
	github.com/spf13/viper v1.19.0
	go.mongodb.org/mongo-driver v1.15.0
	go.uber.org/zap v1.27.0
	golang.org/x/crypto v0.24.0
	golang.org/x/time v0.5.0
	gopkg.in/yaml.v3 v3.0.1
	gorm.io/driver/mysql v1.5.7
	gorm.io/driver/postgres v1.5.9
	gorm.io/gorm v1.25.10
)
"

# ============================================================================
# configs/config.yaml
# ============================================================================
step "Generating configs/config.yaml"
write_file "configs/config.yaml" "app:
  name: \"${PROJECT_NAME}\"
  env: \"development\"
  port: ${APP_PORT}
  host: \"0.0.0.0\"
db:
  driver: \"${DB_DRIVER}\"
  host: \"localhost\"
  port: ${DB_PORT}
  user: \"${DB_DRIVER}\"
  password: \"${DB_DRIVER}\"
  name: \"${PROJECT_NAME}\"
  sslmode: \"disable\"
  max_idle_conns: 10
  max_open_conns: 100
redis:
  host: \"localhost\"
  port: 6379
  password: \"\"
  db: 0
auth:
  jwt_secret: \"${JWT_SECRET}\"
  access_token_expiry: \"24h\"
  refresh_token_expiry: \"168h\"
log:
  level: \"info\"
  format: \"json\"
cors:
  allowed_origins: [\"*\"]
  allowed_methods: [GET, POST, PUT, DELETE, OPTIONS]
ratelimit:
  requests_per_second: 20
  burst: 40
"

# ============================================================================
# .env.example (comprehensive)
# ============================================================================
write_file ".env.example" "# ===== App =====
APP_ENV=development
APP_NAME=${PROJECT_NAME}
APP_PORT=${APP_PORT}
APP_HOST=0.0.0.0

# ===== Database =====
DB_DRIVER=${DB_DRIVER}
DB_HOST=localhost
DB_PORT=${DB_PORT}
DB_USER=${DB_DRIVER}
DB_PASSWORD=${DB_DRIVER}
DB_NAME=${PROJECT_NAME}
DB_SSLMODE=disable
DB_MAX_IDLE_CONNS=10
DB_MAX_OPEN_CONNS=100

# ===== Redis =====
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# ===== Auth =====
JWT_SECRET=${JWT_SECRET}
AUTH_ACCESS_TOKEN_EXPIRY=24h
AUTH_REFRESH_TOKEN_EXPIRY=168h

# ===== Logging =====
LOG_LEVEL=info
LOG_FORMAT=json

# ===== CORS =====
CORS_ALLOWED_ORIGINS=*
CORS_ALLOWED_METHODS=GET,POST,PUT,DELETE,OPTIONS

# ===== Rate Limit =====
RATELIMIT_REQUESTS_PER_SECOND=20
RATELIMIT_BURST=40
"

# ============================================================================
# .gitignore
# ============================================================================
write_file ".gitignore" ".env
*.exe
*.test
*.out
vendor/
tmp/
.idea/
.vscode/
"

# ============================================================================
# internal/config/config.go (with godotenv + priority: ENV > .env > YAML > defaults)
# ============================================================================
step "Generating internal packages"

cat > "$ROOT/internal/config/config.go" <<'EOF'
package config

import (
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"github.com/spf13/viper"
)

type Config struct {
	App       AppConfig       `mapstructure:"app"`
	DB        DBConfig        `mapstructure:"db"`
	Redis     RedisConfig     `mapstructure:"redis"`
	Auth      AuthConfig      `mapstructure:"auth"`
	Log       LogConfig       `mapstructure:"log"`
	CORS      CORSConfig      `mapstructure:"cors"`
	RateLimit RateLimitConfig `mapstructure:"ratelimit"`
}

type AppConfig struct {
	Name string `mapstructure:"name"`
	Env  string `mapstructure:"env"`
	Port int    `mapstructure:"port"`
	Host string `mapstructure:"host"`
}

type DBConfig struct {
	Driver       string `mapstructure:"driver"`
	Host         string `mapstructure:"host"`
	Port         int    `mapstructure:"port"`
	User         string `mapstructure:"user"`
	Password     string `mapstructure:"password"`
	Name         string `mapstructure:"name"`
	SSLMode      string `mapstructure:"sslmode"`
	MaxIdleConns int    `mapstructure:"max_idle_conns"`
	MaxOpenConns int    `mapstructure:"max_open_conns"`
}

type RedisConfig struct {
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	Password string `mapstructure:"password"`
	DB       int    `mapstructure:"db"`
}

type AuthConfig struct {
	JWTSecret          string        `mapstructure:"jwt_secret"`
	AccessTokenExpiry  time.Duration `mapstructure:"access_token_expiry"`
	RefreshTokenExpiry time.Duration `mapstructure:"refresh_token_expiry"`
}

type LogConfig struct {
	Level  string `mapstructure:"level"`
	Format string `mapstructure:"format"`
}

type CORSConfig struct {
	AllowedOrigins []string `mapstructure:"allowed_origins"`
	AllowedMethods []string `mapstructure:"allowed_methods"`
}

type RateLimitConfig struct {
	RequestsPerSecond float64 `mapstructure:"requests_per_second"`
	Burst             int     `mapstructure:"burst"`
}

// LoadEnv loads .env file if present. Safe to call multiple times.
func LoadEnv() {
	_ = godotenv.Load()
}

// Load reads config with priority: ENV > .env > YAML > defaults.
func Load(path string) (*Config, error) {
	LoadEnv()

	v := viper.New()
	v.SetConfigType("yaml")

	// YAML is optional — .env alone is enough
	if _, err := os.Stat(path); err == nil {
		v.SetConfigFile(path)
		if err := v.ReadInConfig(); err != nil {
			return nil, fmt.Errorf("read config: %w", err)
		}
	}

	// ENV vars override everything
	v.AutomaticEnv()
	v.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))

	// Defaults
	v.SetDefault("app.name", "go-microservice")
	v.SetDefault("app.env", "development")
	v.SetDefault("app.port", 8080)
	v.SetDefault("app.host", "0.0.0.0")

	v.SetDefault("db.driver", "postgres")
	v.SetDefault("db.host", "localhost")
	v.SetDefault("db.port", 5432)
	v.SetDefault("db.user", "postgres")
	v.SetDefault("db.password", "postgres")
	v.SetDefault("db.name", "mydb")
	v.SetDefault("db.sslmode", "disable")
	v.SetDefault("db.max_idle_conns", 10)
	v.SetDefault("db.max_open_conns", 100)

	v.SetDefault("redis.host", "localhost")
	v.SetDefault("redis.port", 6379)
	v.SetDefault("redis.db", 0)

	v.SetDefault("auth.access_token_expiry", "24h")
	v.SetDefault("auth.refresh_token_expiry", "168h")

	v.SetDefault("log.level", "info")
	v.SetDefault("log.format", "json")

	v.SetDefault("cors.allowed_origins", []string{"*"})
	v.SetDefault("cors.allowed_methods", []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"})

	v.SetDefault("ratelimit.requests_per_second", 20)
	v.SetDefault("ratelimit.burst", 40)

	var cfg Config
	if err := v.Unmarshal(&cfg); err != nil {
		return nil, fmt.Errorf("unmarshal config: %w", err)
	}
	return &cfg, nil
}
EOF
ok "wrote internal/config/config.go"

# ============================================================================
# pkg/logger/logger.go
# ============================================================================
cat > "$ROOT/pkg/logger/logger.go" <<'EOF'
package logger

import (
	"os"
	"strings"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Log *zap.Logger

func Init(level, format string) {
	var lvl zapcore.Level
	switch strings.ToLower(level) {
	case "debug":
		lvl = zapcore.DebugLevel
	case "warn":
		lvl = zapcore.WarnLevel
	case "error":
		lvl = zapcore.ErrorLevel
	default:
		lvl = zapcore.InfoLevel
	}
	encCfg := zap.NewProductionEncoderConfig()
	encCfg.EncodeTime = zapcore.ISO8601TimeEncoder
	encCfg.EncodeLevel = zapcore.LowercaseLevelEncoder
	var enc zapcore.Encoder
	if strings.ToLower(format) == "console" {
		enc = zapcore.NewConsoleEncoder(encCfg)
	} else {
		enc = zapcore.NewJSONEncoder(encCfg)
	}
	Log = zap.New(zapcore.NewCore(enc, zapcore.AddSync(os.Stdout), lvl),
		zap.AddCaller(), zap.AddStacktrace(zapcore.ErrorLevel))
}

func Info(msg string, f ...zap.Field)  { Log.Info(msg, f...) }
func Warn(msg string, f ...zap.Field)  { Log.Warn(msg, f...) }
func Error(msg string, f ...zap.Field) { Log.Error(msg, f...) }
func Debug(msg string, f ...zap.Field) { Log.Debug(msg, f...) }
EOF
ok "wrote pkg/logger/logger.go"

# ============================================================================
# pkg/response/response.go
# ============================================================================
cat > "$ROOT/pkg/response/response.go" <<'EOF'
package response

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Response struct {
	Success bool        `json:"success"`
	Message string      `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

func JSON(c *gin.Context, code int, ok bool, msg string, data interface{}) {
	c.JSON(code, Response{Success: ok, Message: msg, Data: data})
}
func OK(c *gin.Context, data interface{})       { JSON(c, http.StatusOK, true, "ok", data) }
func Created(c *gin.Context, data interface{})  { JSON(c, http.StatusCreated, true, "created", data) }
func BadRequest(c *gin.Context, msg string)     { JSON(c, http.StatusBadRequest, false, msg, nil) }
func Unauthorized(c *gin.Context, msg string)   { JSON(c, http.StatusUnauthorized, false, msg, nil) }
func Forbidden(c *gin.Context, msg string)      { JSON(c, http.StatusForbidden, false, msg, nil) }
func NotFound(c *gin.Context, msg string)       { JSON(c, http.StatusNotFound, false, msg, nil) }
func Internal(c *gin.Context, msg string)       { JSON(c, http.StatusInternalServerError, false, msg, nil) }
EOF
ok "wrote pkg/response/response.go"

# ============================================================================
# pkg/utils/password.go & validator.go
# ============================================================================
cat > "$ROOT/pkg/utils/password.go" <<'EOF'
package utils

import "golang.org/x/crypto/bcrypt"

func HashPassword(pw string) (string, error) {
	b, err := bcrypt.GenerateFromPassword([]byte(pw), bcrypt.DefaultCost)
	return string(b), err
}
func CheckPassword(hash, pw string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(pw)) == nil
}
EOF

cat > "$ROOT/pkg/utils/validator.go" <<'EOF'
package utils

import (
	"errors"
	"regexp"
	"strings"
)

var emailRe = regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)

func ValidateEmail(e string) error {
	if !emailRe.MatchString(strings.TrimSpace(e)) {
		return errors.New("invalid email")
	}
	return nil
}
EOF
ok "wrote pkg/utils/*"

# ============================================================================
# db/*.go
# ============================================================================
step "Generating database adapters"

cat > "$ROOT/db/postgres.go" <<'EOF'
package db

import (
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

type DBConfig struct {
	Host, User, Password, Name, SSLMode string
	Port, MaxIdleConns, MaxOpenConns    int
}

func NewPostgres(cfg *DBConfig) (*gorm.DB, error) {
	dsn := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Name, cfg.SSLMode)
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{Logger: logger.Default.LogMode(logger.Warn)})
	if err != nil {
		return nil, err
	}
	sqlDB, _ := db.DB()
	sqlDB.SetMaxIdleConns(cfg.MaxIdleConns)
	sqlDB.SetMaxOpenConns(cfg.MaxOpenConns)
	sqlDB.SetConnMaxLifetime(time.Hour)
	return db, nil
}
EOF

cat > "$ROOT/db/mysql.go" <<'EOF'
package db

import (
	"fmt"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

type MySQLConfig struct {
	Host, User, Password, Name string
	Port                       int
}

func NewMySQL(cfg *MySQLConfig) (*gorm.DB, error) {
	dsn := fmt.Sprintf("%s:%s@tcp(%s:%d)/%s?charset=utf8mb4&parseTime=True&loc=Local",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.Name)
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, err
	}
	sqlDB, _ := db.DB()
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(100)
	sqlDB.SetConnMaxLifetime(time.Hour)
	return db, nil
}
EOF

cat > "$ROOT/db/mongodb.go" <<'EOF'
package db

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

type MongoConfig struct {
	URI, Database string
}

func NewMongo(cfg *MongoConfig) (*mongo.Client, *mongo.Database, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	client, err := mongo.Connect(ctx, options.Client().ApplyURI(cfg.URI))
	if err != nil {
		return nil, nil, err
	}
	if err := client.Ping(ctx, nil); err != nil {
		return nil, nil, err
	}
	return client, client.Database(cfg.Database), nil
}
EOF

cat > "$ROOT/db/redis.go" <<'EOF'
package db

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

type RedisConfig struct {
	Host, Password string
	Port, DB       int
}

func NewRedis(cfg *RedisConfig) (*redis.Client, error) {
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%d", cfg.Host, cfg.Port),
		Password: cfg.Password,
		DB:       cfg.DB,
	})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		return nil, err
	}
	return rdb, nil
}
EOF
ok "wrote db/*.go"

# ============================================================================
# internal/model/user.go & dto.go
# ============================================================================
step "Generating domain models"

cat > "$ROOT/internal/model/user.go" <<'EOF'
package model

import (
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Role string

const (
	RoleUser  Role = "user"
	RoleAdmin Role = "admin"
)

type User struct {
	ID        uuid.UUID  `gorm:"type:uuid;primary_key" json:"id"`
	Email     string     `gorm:"uniqueIndex;size:255;not null" json:"email"`
	Name      string     `gorm:"size:120;not null" json:"name"`
	Password  string     `gorm:"size:255;not null" json:"-"`
	Role      Role       `gorm:"size:20;default:'user'" json:"role"`
	CreatedAt time.Time  `json:"created_at"`
	UpdatedAt time.Time  `json:"updated_at"`
	DeletedAt *time.Time `gorm:"index" json:"-"`
}

func (u *User) BeforeCreate(tx *gorm.DB) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	return nil
}
EOF

cat > "$ROOT/internal/model/dto.go" <<'EOF'
package model

type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Name     string `json:"name" binding:"required,min=2"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

type AuthResponse struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	ExpiresIn    int64  `json:"expires_in"`
	User         User   `json:"user"`
}

type UserResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Name  string `json:"name"`
	Role  string `json:"role"`
}

func ToUserResponse(u *User) UserResponse {
	return UserResponse{ID: u.ID.String(), Email: u.Email, Name: u.Name, Role: string(u.Role)}
}
EOF
ok "wrote internal/model/*"

# ============================================================================
# internal/auth/jwt.go
# ============================================================================
step "Generating auth layer"

cat > "$ROOT/internal/auth/jwt.go" <<'EOF'
package auth

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

type Claims struct {
	UserID string `json:"user_id"`
	Email  string `json:"email"`
	Role   string `json:"role"`
	jwt.RegisteredClaims
}

type JWTManager struct {
	secret        []byte
	accessExpiry  time.Duration
	refreshExpiry time.Duration
}

func NewJWTManager(secret string, access, refresh time.Duration) *JWTManager {
	return &JWTManager{secret: []byte(secret), accessExpiry: access, refreshExpiry: refresh}
}

func (j *JWTManager) GenerateAccessToken(uid, email, role string) (string, int64, error) {
	exp := time.Now().Add(j.accessExpiry)
	c := Claims{UserID: uid, Email: email, Role: role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(exp),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ID:        uuid.NewString(),
		}}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, c)
	s, err := t.SignedString(j.secret)
	return s, int64(j.accessExpiry.Seconds()), err
}

func (j *JWTManager) GenerateRefreshToken(uid string) (string, error) {
	c := Claims{UserID: uid, RegisteredClaims: jwt.RegisteredClaims{
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(j.refreshExpiry)),
		ID:        uuid.NewString(),
	}}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, c).SignedString(j.secret)
}

func (j *JWTManager) Validate(s string) (*Claims, error) {
	t, err := jwt.ParseWithClaims(s, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("bad signing method")
		}
		return j.secret, nil
	})
	if err != nil || !t.Valid {
		return nil, errors.New("invalid token")
	}
	c, ok := t.Claims.(*Claims)
	if !ok {
		return nil, errors.New("bad claims")
	}
	return c, nil
}
EOF
ok "wrote internal/auth/jwt.go"

# ============================================================================
# internal/middleware/*.go
# ============================================================================
step "Generating middleware"

cat > "$ROOT/internal/middleware/requestid.go" <<'EOF'
package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		rid := c.GetHeader("X-Request-ID")
		if rid == "" {
			rid = uuid.NewString()
		}
		c.Set("request_id", rid)
		c.Header("X-Request-ID", rid)
		c.Next()
	}
}
EOF

cat > "$ROOT/internal/middleware/recovery.go" <<EOF
package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"${MODULE_PATH}/pkg/logger"
	"${MODULE_PATH}/pkg/response"
)

func Recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				logger.Error("panic", zap.Any("err", r))
				response.Internal(c, "internal server error")
				c.AbortWithStatus(http.StatusInternalServerError)
			}
		}()
		c.Next()
	}
}
EOF

cat > "$ROOT/internal/middleware/logger.go" <<EOF
package middleware

import (
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
	"${MODULE_PATH}/pkg/logger"
)

func AccessLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		rid, _ := c.Get("request_id")
		logger.Info("http",
			zap.Any("request_id", rid),
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("latency", time.Since(start)),
		)
	}
}
EOF

cat > "$ROOT/internal/middleware/auth.go" <<EOF
package middleware

import (
	"strings"

	"github.com/gin-gonic/gin"
	"${MODULE_PATH}/internal/auth"
	"${MODULE_PATH}/pkg/response"
)

const (
	CtxUserID = "user_id"
	CtxEmail  = "email"
	CtxRole   = "role"
)

func AuthRequired(j *auth.JWTManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		if !strings.HasPrefix(h, "Bearer ") {
			response.Unauthorized(c, "missing bearer token")
			c.Abort()
			return
		}
		claims, err := j.Validate(strings.TrimPrefix(h, "Bearer "))
		if err != nil {
			response.Unauthorized(c, err.Error())
			c.Abort()
			return
		}
		c.Set(CtxUserID, claims.UserID)
		c.Set(CtxEmail, claims.Email)
		c.Set(CtxRole, claims.Role)
		c.Next()
	}
}

func RequireRole(roles ...string) gin.HandlerFunc {
	set := map[string]struct{}{}
	for _, r := range roles {
		set[r] = struct{}{}
	}
	return func(c *gin.Context) {
		role, _ := c.Get(CtxRole)
		if _, ok := set[role.(string)]; !ok {
			response.Forbidden(c, "insufficient permissions")
			c.Abort()
			return
		}
		c.Next()
	}
}
EOF

cat > "$ROOT/internal/middleware/cors.go" <<'EOF'
package middleware

import (
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

type CORSConfig struct {
	AllowedOrigins []string
	AllowedMethods []string
}

func CORS(cfg CORSConfig) gin.HandlerFunc {
	return cors.New(cors.Config{
		AllowOrigins:     cfg.AllowedOrigins,
		AllowMethods:     cfg.AllowedMethods,
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID"},
		ExposeHeaders:    []string{"Content-Length", "X-Request-ID"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour,
	})
}
EOF

cat > "$ROOT/internal/middleware/ratelimit.go" <<EOF
package middleware

import (
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
	"${MODULE_PATH}/pkg/response"
)

type rl struct {
	mu       sync.Mutex
	visitors map[string]*rate.Limiter
	r        rate.Limit
	burst    int
}

func RateLimit(rps float64, burst int) gin.HandlerFunc {
	l := &rl{visitors: map[string]*rate.Limiter{}, r: rate.Limit(rps), burst: burst}
	return func(c *gin.Context) {
		l.mu.Lock()
		lim, ok := l.visitors[c.ClientIP()]
		if !ok {
			lim = rate.NewLimiter(l.r, l.burst)
			l.visitors[c.ClientIP()] = lim
		}
		l.mu.Unlock()
		if !lim.Allow() {
			response.JSON(c, http.StatusTooManyRequests, false, "too many requests", nil)
			c.Abort()
			return
		}
		c.Next()
	}
}
EOF
ok "wrote internal/middleware/*"

# ============================================================================
# internal/repository/user_repository.go
# ============================================================================
step "Generating repository layer"

cat > "$ROOT/internal/repository/user_repository.go" <<EOF
package repository

import (
	"context"

	"github.com/google/uuid"
	"${MODULE_PATH}/internal/model"
	"gorm.io/gorm"
)

type UserRepository interface {
	Create(ctx context.Context, u *model.User) error
	FindByEmail(ctx context.Context, email string) (*model.User, error)
	FindByID(ctx context.Context, id uuid.UUID) (*model.User, error)
	List(ctx context.Context, limit, offset int) ([]model.User, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

type userRepo struct{ db *gorm.DB }

func NewUserRepository(db *gorm.DB) UserRepository { return &userRepo{db: db} }

func (r *userRepo) Create(ctx context.Context, u *model.User) error {
	return r.db.WithContext(ctx).Create(u).Error
}
func (r *userRepo) FindByEmail(ctx context.Context, email string) (*model.User, error) {
	var u model.User
	if err := r.db.WithContext(ctx).Where("email = ?", email).First(&u).Error; err != nil {
		return nil, err
	}
	return &u, nil
}
func (r *userRepo) FindByID(ctx context.Context, id uuid.UUID) (*model.User, error) {
	var u model.User
	if err := r.db.WithContext(ctx).First(&u, "id = ?", id).Error; err != nil {
		return nil, err
	}
	return &u, nil
}
func (r *userRepo) List(ctx context.Context, limit, offset int) ([]model.User, error) {
	var users []model.User
	err := r.db.WithContext(ctx).Limit(limit).Offset(offset).Order("created_at DESC").Find(&users).Error
	return users, err
}
func (r *userRepo) Delete(ctx context.Context, id uuid.UUID) error {
	return r.db.WithContext(ctx).Delete(&model.User{}, "id = ?", id).Error
}
EOF
ok "wrote internal/repository/user_repository.go"

# ============================================================================
# internal/service/user_service.go
# ============================================================================
step "Generating service layer"

cat > "$ROOT/internal/service/user_service.go" <<EOF
package service

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"${MODULE_PATH}/internal/auth"
	"${MODULE_PATH}/internal/model"
	"${MODULE_PATH}/internal/repository"
	"${MODULE_PATH}/pkg/utils"
	"gorm.io/gorm"
)

var (
	ErrEmailExists  = errors.New("email already registered")
	ErrInvalidCreds = errors.New("invalid credentials")
	ErrUserNotFound = errors.New("user not found")
)

type UserService struct {
	repo   repository.UserRepository
	jwtMgr *auth.JWTManager
}

func NewUserService(r repository.UserRepository, j *auth.JWTManager) *UserService {
	return &UserService{repo: r, jwtMgr: j}
}

func (s *UserService) Register(ctx context.Context, req model.RegisterRequest) (*model.AuthResponse, error) {
	if _, err := s.repo.FindByEmail(ctx, req.Email); err == nil {
		return nil, ErrEmailExists
	}
	hash, err := utils.HashPassword(req.Password)
	if err != nil {
		return nil, err
	}
	u := &model.User{Email: req.Email, Name: req.Name, Password: hash, Role: model.RoleUser}
	if err := s.repo.Create(ctx, u); err != nil {
		return nil, err
	}
	return s.tokens(u)
}

func (s *UserService) Login(ctx context.Context, req model.LoginRequest) (*model.AuthResponse, error) {
	u, err := s.repo.FindByEmail(ctx, req.Email)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrInvalidCreds
		}
		return nil, err
	}
	if !utils.CheckPassword(u.Password, req.Password) {
		return nil, ErrInvalidCreds
	}
	return s.tokens(u)
}

func (s *UserService) List(ctx context.Context, limit, offset int) ([]model.UserResponse, error) {
	users, err := s.repo.List(ctx, limit, offset)
	if err != nil {
		return nil, err
	}
	out := make([]model.UserResponse, 0, len(users))
	for _, u := range users {
		out = append(out, model.ToUserResponse(&u))
	}
	return out, nil
}

func (s *UserService) GetByID(ctx context.Context, id string) (*model.UserResponse, error) {
	uid, err := uuid.Parse(id)
	if err != nil {
		return nil, ErrUserNotFound
	}
	u, err := s.repo.FindByID(ctx, uid)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	r := model.ToUserResponse(u)
	return &r, nil
}

func (s *UserService) Delete(ctx context.Context, id string) error {
	uid, err := uuid.Parse(id)
	if err != nil {
		return ErrUserNotFound
	}
	return s.repo.Delete(ctx, uid)
}

func (s *UserService) tokens(u *model.User) (*model.AuthResponse, error) {
	access, exp, err := s.jwtMgr.GenerateAccessToken(u.ID.String(), u.Email, string(u.Role))
	if err != nil {
		return nil, err
	}
	refresh, err := s.jwtMgr.GenerateRefreshToken(u.ID.String())
	if err != nil {
		return nil, err
	}
	return &model.AuthResponse{AccessToken: access, RefreshToken: refresh, ExpiresIn: exp, User: *u}, nil
}
EOF
ok "wrote internal/service/user_service.go"

# ============================================================================
# internal/handler/*.go
# ============================================================================
step "Generating handlers"

cat > "$ROOT/internal/handler/health.go" <<EOF
package handler

import (
	"github.com/gin-gonic/gin"
	"${MODULE_PATH}/pkg/response"
)

type HealthHandler struct{}

func NewHealthHandler() *HealthHandler { return &HealthHandler{} }
func (h *HealthHandler) Check(c *gin.Context) { response.OK(c, gin.H{"status": "healthy"}) }
EOF

cat > "$ROOT/internal/handler/user.go" <<EOF
package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"${MODULE_PATH}/internal/middleware"
	"${MODULE_PATH}/internal/model"
	"${MODULE_PATH}/internal/service"
	"${MODULE_PATH}/pkg/response"
)

type UserHandler struct{ svc *service.UserService }

func NewUserHandler(s *service.UserService) *UserHandler { return &UserHandler{svc: s} }

func (h *UserHandler) Register(c *gin.Context) {
	var req model.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	auth, err := h.svc.Register(c.Request.Context(), req)
	if err != nil {
		if errors.Is(err, service.ErrEmailExists) {
			response.JSON(c, http.StatusConflict, false, err.Error(), nil)
			return
		}
		response.Internal(c, "registration failed")
		return
	}
	response.Created(c, auth)
}

func (h *UserHandler) Login(c *gin.Context) {
	var req model.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		response.BadRequest(c, err.Error())
		return
	}
	auth, err := h.svc.Login(c.Request.Context(), req)
	if err != nil {
		response.Unauthorized(c, err.Error())
		return
	}
	response.OK(c, auth)
}

func (h *UserHandler) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	users, err := h.svc.List(c.Request.Context(), limit, offset)
	if err != nil {
		response.Internal(c, "list failed")
		return
	}
	response.OK(c, users)
}

func (h *UserHandler) Get(c *gin.Context) {
	u, err := h.svc.GetByID(c.Request.Context(), c.Param("id"))
	if err != nil {
		response.NotFound(c, err.Error())
		return
	}
	response.OK(c, u)
}

func (h *UserHandler) Delete(c *gin.Context) {
	id := c.Param("id")
	authedID, _ := c.Get(middleware.CtxUserID)
	role, _ := c.Get(middleware.CtxRole)
	if role != "admin" && authedID != id {
		response.Forbidden(c, "forbidden")
		return
	}
	if err := h.svc.Delete(c.Request.Context(), id); err != nil {
		response.NotFound(c, err.Error())
		return
	}
	response.OK(c, gin.H{"deleted": id})
}
EOF
ok "wrote internal/handler/*"

# ============================================================================
# internal/router/router.go
# ============================================================================
step "Generating router"

cat > "$ROOT/internal/router/router.go" <<EOF
package router

import (
	"github.com/gin-gonic/gin"
	"${MODULE_PATH}/internal/auth"
	"${MODULE_PATH}/internal/handler"
	"${MODULE_PATH}/internal/middleware"
)

type Deps struct {
	JWT    *auth.JWTManager
	User   *handler.UserHandler
	Health *handler.HealthHandler
	CORS   middleware.CORSConfig
	RPS    float64
	Burst  int
}

func Setup(d Deps) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.RequestID())
	r.Use(middleware.Recovery())
	r.Use(middleware.AccessLogger())
	r.Use(middleware.CORS(middleware.CORSConfig{
		AllowedOrigins: d.CORS.AllowedOrigins, AllowedMethods: d.CORS.AllowedMethods,
	}))
	r.Use(middleware.RateLimit(d.RPS, d.Burst))

	r.GET("/health", d.Health.Check)

	v1 := r.Group("/api/v1")
	{
		auth := v1.Group("/auth")
		auth.POST("/register", d.User.Register)
		auth.POST("/login", d.User.Login)

		users := v1.Group("/users")
		users.Use(middleware.AuthRequired(d.JWT))
		users.GET("", d.User.List)
		users.GET("/:id", d.User.Get)
		users.DELETE("/:id", d.User.Delete)
	}
	return r
}
EOF
ok "wrote internal/router/router.go"

# ============================================================================
# cmd/server/main.go (with config.LoadEnv() call)
# ============================================================================
step "Generating cmd/server/main.go"

cat > "$ROOT/cmd/server/main.go" <<EOF
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"${MODULE_PATH}/db"
	"${MODULE_PATH}/internal/auth"
	"${MODULE_PATH}/internal/config"
	"${MODULE_PATH}/internal/handler"
	"${MODULE_PATH}/internal/middleware"
	"${MODULE_PATH}/internal/model"
	"${MODULE_PATH}/internal/repository"
	"${MODULE_PATH}/internal/router"
	"${MODULE_PATH}/internal/service"
	"${MODULE_PATH}/pkg/logger"
	"go.uber.org/zap"
	"gorm.io/gorm"
)

func main() {
	// Load .env FIRST (before config parsing)
	config.LoadEnv()

	cfg, err := config.Load("configs/config.yaml")
	if err != nil {
		fmt.Fprintln(os.Stderr, "config:", err)
		os.Exit(1)
	}

	logger.Init(cfg.Log.Level, cfg.Log.Format)
	defer logger.Log.Sync()
	logger.Info("starting", zap.String("app", cfg.App.Name), zap.Int("port", cfg.App.Port))

	var gormDB *gorm.DB
	switch cfg.DB.Driver {
	case "postgres":
		gormDB, err = db.NewPostgres(&db.DBConfig{
			Host: cfg.DB.Host, Port: cfg.DB.Port, User: cfg.DB.User,
			Password: cfg.DB.Password, Name: cfg.DB.Name, SSLMode: cfg.DB.SSLMode,
			MaxIdleConns: cfg.DB.MaxIdleConns, MaxOpenConns: cfg.DB.MaxOpenConns,
		})
	case "mysql":
		gormDB, err = db.NewMySQL(&db.MySQLConfig{
			Host: cfg.DB.Host, Port: cfg.DB.Port, User: cfg.DB.User,
			Password: cfg.DB.Password, Name: cfg.DB.Name,
		})
	default:
		logger.Error("unsupported db driver", zap.String("driver", cfg.DB.Driver))
		os.Exit(1)
	}
	if err != nil {
		logger.Error("db", zap.Error(err))
		os.Exit(1)
	}

	if err := gormDB.AutoMigrate(&model.User{}); err != nil {
		logger.Error("migrate", zap.Error(err))
		os.Exit(1)
	}

	jwtMgr := auth.NewJWTManager(cfg.Auth.JWTSecret, cfg.Auth.AccessTokenExpiry, cfg.Auth.RefreshTokenExpiry)
	userHandler := handler.NewUserHandler(service.NewUserService(repository.NewUserRepository(gormDB), jwtMgr))

	r := router.Setup(router.Deps{
		JWT:    jwtMgr,
		User:   userHandler,
		Health: handler.NewHealthHandler(),
		CORS: middleware.CORSConfig{
			AllowedOrigins: cfg.CORS.AllowedOrigins,
			AllowedMethods: cfg.CORS.AllowedMethods,
		},
		RPS:   cfg.RateLimit.RequestsPerSecond,
		Burst: cfg.RateLimit.Burst,
	})

	addr := fmt.Sprintf("%s:%d", cfg.App.Host, cfg.App.Port)
	srv := &http.Server{Addr: addr, Handler: r}
	go func() {
		logger.Info("listening", zap.String("addr", addr))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("http", zap.Error(err))
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("shutting down")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
	sqlDB, _ := gormDB.DB()
	_ = sqlDB.Close()
	logger.Info("bye")
}
EOF
ok "wrote cmd/server/main.go"

# ============================================================================
# Docker files
# ============================================================================
step "Generating Docker files"

cat > "$ROOT/docker/Dockerfile" <<'EOF'
FROM golang:1.22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/server ./cmd/server

FROM alpine:3.19
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=builder /app/server .
COPY --from=builder /app/configs ./configs
EXPOSE 8080
CMD ["./server"]
EOF

case "$DB_DRIVER" in
postgres)
	DB_SERVICE="  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ${PROJECT_NAME}
    ports: [\"5432:5432\"]
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: [\"CMD-SHELL\", \"pg_isready -U postgres\"]
      interval: 5s
      retries: 5"
	;;
mysql)
	DB_SERVICE="  mysql:
    image: mysql:8
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: ${PROJECT_NAME}
    ports: [\"3306:3306\"]
    volumes: [mydata:/var/lib/mysql]
    healthcheck:
      test: [\"CMD\", \"mysqladmin\", \"ping\", \"-h\", \"localhost\"]
      interval: 5s
      retries: 10"
	;;
mongo)
	DB_SERVICE="  mongo:
    image: mongo:7
    ports: [\"27017:27017\"]
    volumes: [modata:/data/db]"
	;;
esac

cat > "$ROOT/docker-compose.yml" <<EOF
version: "3.9"

services:
  app:
    build:
      context: .
      dockerfile: docker/Dockerfile
    container_name: ${PROJECT_NAME}
    ports: ["${APP_PORT}:${APP_PORT}"]
    environment:
      APP_ENV: development
      DB_HOST: ${DB_DRIVER}
      DB_PORT: ${DB_PORT}
      DB_USER: ${DB_DRIVER}
      DB_PASSWORD: ${DB_DRIVER}
      DB_NAME: ${PROJECT_NAME}
      REDIS_HOST: redis
      JWT_SECRET: ${JWT_SECRET}
      LOG_LEVEL: info
    depends_on:
      ${DB_DRIVER}:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

${DB_SERVICE}

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 5

volumes:
  pgdata:
  mydata:
  modata:
EOF
ok "wrote docker/Dockerfile & docker-compose.yml"

# ============================================================================
# Tests
# ============================================================================
step "Generating tests"

cat > "$ROOT/internal/service/user_service_test.go" <<EOF
package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"${MODULE_PATH}/internal/auth"
	"${MODULE_PATH}/internal/model"
	"${MODULE_PATH}/internal/repository"
	"gorm.io/gorm"
)

type mockRepo struct{ users map[string]*model.User }

func newMock() *mockRepo { return &mockRepo{users: map[string]*model.User{}} }
func (m *mockRepo) Create(_ context.Context, u *model.User) error {
	if u.ID == uuid.Nil {
		u.ID = uuid.New()
	}
	m.users[u.Email] = u
	return nil
}
func (m *mockRepo) FindByEmail(_ context.Context, email string) (*model.User, error) {
	if u, ok := m.users[email]; ok {
		return u, nil
	}
	return nil, gorm.ErrRecordNotFound
}
func (m *mockRepo) FindByID(_ context.Context, id uuid.UUID) (*model.User, error) {
	for _, u := range m.users {
		if u.ID == id {
			return u, nil
		}
	}
	return nil, gorm.ErrRecordNotFound
}
func (m *mockRepo) List(_ context.Context, _, _ int) ([]model.User, error) {
	out := make([]model.User, 0, len(m.users))
	for _, u := range m.users {
		out = append(out, *u)
	}
	return out, nil
}
func (m *mockRepo) Delete(_ context.Context, id uuid.UUID) error {
	for k, u := range m.users {
		if u.ID == id {
			delete(m.users, k)
			return nil
		}
	}
	return errors.New("not found")
}

var _ repository.UserRepository = (*mockRepo)(nil)

func TestRegisterAndLogin(t *testing.T) {
	svc := NewUserService(newMock(), auth.NewJWTManager("s", time.Hour, time.Hour*24))
	ctx := context.Background()
	a, err := svc.Register(ctx, model.RegisterRequest{Email: "a@b.com", Name: "A", Password: "password123"})
	if err != nil {
		t.Fatal(err)
	}
	if a.AccessToken == "" {
		t.Fatal("no token")
	}
	if _, err := svc.Register(ctx, model.RegisterRequest{Email: "a@b.com", Name: "A", Password: "password123"}); !errors.Is(err, ErrEmailExists) {
		t.Fatalf("expected ErrEmailExists, got %v", err)
	}
	if _, err := svc.Login(ctx, model.LoginRequest{Email: "a@b.com", Password: "password123"}); err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Login(ctx, model.LoginRequest{Email: "a@b.com", Password: "wrong"}); !errors.Is(err, ErrInvalidCreds) {
		t.Fatalf("expected ErrInvalidCreds, got %v", err)
	}
}
EOF
ok "wrote tests"

# ============================================================================
# README
# ============================================================================
step "Generating README"

cat > "$ROOT/README.md" <<EOF
# ${PROJECT_NAME}

Production Go microservice generated by go-scaffold.

## Quick Start

### Option 1: Using .env (recommended)

\`\`\`bash
cp .env.example .env
# Edit .env with your values
go mod tidy
go run ./cmd/server
\`\`\`

### Option 2: Using config.yaml

\`\`\`bash
# Edit configs/config.yaml
go mod tidy
go run ./cmd/server
\`\`\`

### Option 3: Using Docker

\`\`\`bash
docker-compose up --build
\`\`\`

Service: http://localhost:${APP_PORT}

## Configuration Priority

1. **System ENV vars** (highest) — \`export DB_PORT=5433\`
2. **\`.env\` file** — \`DB_PORT=5433\`
3. **\`configs/config.yaml\`** — \`db.port: 5433\`
4. **Built-in defaults** (lowest)

## ENV Variable Mapping

| YAML Key | ENV Variable |
|----------|--------------|
| app.port | APP_PORT |
| db.host | DB_HOST |
| db.port | DB_PORT |
| db.user | DB_USER |
| db.password | DB_PASSWORD |
| db.name | DB_NAME |
| redis.host | REDIS_HOST |
| jwt_secret | JWT_SECRET |
| log.level | LOG_LEVEL |

## Endpoints

| Method | Path                  | Auth |
|--------|-----------------------|------|
| GET    | /health               | No   |
| POST   | /api/v1/auth/register | No   |
| POST   | /api/v1/auth/login    | No   |
| GET    | /api/v1/users         | Yes  |
| GET    | /api/v1/users/:id     | Yes  |
| DELETE | /api/v1/users/:id     | Yes  |

## Tests

\`\`\`bash
go test ./...
\`\`\`
EOF
ok "wrote README.md"

# ============================================================================
# Finalize
# ============================================================================
step "Finalizing"

if command -v go >/dev/null 2>&1; then
  info "Running go mod tidy..."
  (cd "$ROOT" && go mod tidy 2>&1 | sed 's/^/       /') || warn "go mod tidy had warnings"
else
  warn "Go not found — run 'go mod tidy' manually"
fi

if command -v git >/dev/null 2>&1 && [[ ! -d "$ROOT/.git" ]]; then
  (cd "$ROOT" && git init -q && git add -A && git commit -q -m "Initial scaffold: ${PROJECT_NAME}" >/dev/null)
  ok "Initialized git repository"
fi

echo
echo -e "${GREEN}${BOLD}✅ Project generated successfully!${NC}"
echo
echo -e "  ${BOLD}Location:${NC}  $(cd "$ROOT" && pwd)"
echo -e "  ${BOLD}Module:${NC}    ${MODULE_PATH}"
echo -e "  ${BOLD}Database:${NC}  ${DB_DRIVER}"
echo -e "  ${BOLD}Port:${NC}      ${APP_PORT}"
echo
echo -e "${BOLD}Next steps:${NC}"
echo -e "  ${CYAN}cd ${OUTPUT_DIR}${NC}"
echo -e "  ${CYAN}cp .env.example .env${NC}          # configure via .env"
echo -e "  ${CYAN}go mod tidy${NC}                   # download deps"
echo -e "  ${CYAN}go run ./cmd/server${NC}           # run locally"
echo -e "  ${CYAN}docker-compose up --build${NC}     # or run with Docker"
echo -e "  ${CYAN}go test ./...${NC}                 # run tests"
echo
echo -e "${BOLD}Try it:${NC}"
echo -e "  ${CYAN}curl http://localhost:${APP_PORT}/health${NC}"
echo
echo -e "${GREEN}Happy coding! 🚀${NC}"