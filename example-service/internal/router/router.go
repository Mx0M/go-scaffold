package router

import (
	"github.com/gin-gonic/gin"
	"github.com/you/example-service/internal/auth"
	"github.com/you/example-service/internal/handler"
	"github.com/you/example-service/internal/middleware"
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
