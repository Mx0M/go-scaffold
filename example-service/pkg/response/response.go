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
