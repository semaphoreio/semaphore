package gitrekt

import "fmt"

type NotFoundError struct {
	Output string
}

func (e *NotFoundError) Error() string {
	return fmt.Sprintf("repository not found: %s", e.Output)
}

type AuthFailedError struct {
	Output string
}

func (e *AuthFailedError) Error() string {
	return fmt.Sprintf("authentication failed: %s", e.Output)
}

type TimeoutError struct {
	Output string
}

func (e *TimeoutError) Error() string {
	return fmt.Sprintf("timeout: %s", e.Output)
}
