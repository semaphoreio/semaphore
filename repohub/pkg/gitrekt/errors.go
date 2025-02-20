package gitrekt

type NotFoundError struct{ error }
type AuthFailedError struct{ error }

type TimeoutError struct{ error }
type AuthTimeoutError struct{ error }
