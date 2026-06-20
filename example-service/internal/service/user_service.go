package service

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/you/example-service/internal/auth"
	"github.com/you/example-service/internal/model"
	"github.com/you/example-service/internal/repository"
	"github.com/you/example-service/pkg/utils"
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
