package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/you/example-service/internal/middleware"
	"github.com/you/example-service/internal/model"
	"github.com/you/example-service/internal/service"
	"github.com/you/example-service/pkg/response"
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
