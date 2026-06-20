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
