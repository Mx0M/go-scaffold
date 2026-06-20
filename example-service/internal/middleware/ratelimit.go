package middleware

import (
	"net/http"
	"sync"

	"github.com/gin-gonic/gin"
	"golang.org/x/time/rate"
	"github.com/you/example-service/pkg/response"
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
