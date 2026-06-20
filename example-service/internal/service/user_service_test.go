package service

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/you/example-service/internal/auth"
	"github.com/you/example-service/internal/model"
	"github.com/you/example-service/internal/repository"
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
