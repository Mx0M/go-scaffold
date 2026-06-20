package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/you/example-service/db"
	"github.com/you/example-service/internal/auth"
	"github.com/you/example-service/internal/config"
	"github.com/you/example-service/internal/handler"
	"github.com/you/example-service/internal/middleware"
	"github.com/you/example-service/internal/model"
	"github.com/you/example-service/internal/repository"
	"github.com/you/example-service/internal/router"
	"github.com/you/example-service/internal/service"
	"github.com/you/example-service/pkg/logger"
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
