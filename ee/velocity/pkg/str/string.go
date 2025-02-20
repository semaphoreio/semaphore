// Package str holds functions to check if strings are empty.
package str

// IsEmpty checks if the value passed is an empty string
func IsEmpty(v string) bool {
	return len(v) == 0
}

// AnyEmpty returns true if at least one of the values passed is an empty string
// case none of the values are empty or there are no values, false is returned.
func AnyEmpty(v ...string) bool {
	for _, str := range v {
		if IsEmpty(str) {
			return true
		}
	}
	return false
}
