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
