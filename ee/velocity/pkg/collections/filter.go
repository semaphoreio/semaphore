//revive:disable support for generics not working with revive
package collections

func Filter[T any](slice []T, f func(T) bool) []T {
	var n []T
	for _, elem := range slice {
		if f(elem) {
			n = append(n, elem)
		}
	}
	return n
}

func Count[T any](slice []T, f func(T) bool) int {
	var n int
	for _, elem := range slice {
		if f(elem) {
			n++
		}
	}
	return n
}

func FirstOrNil[T any](slice []T, f func(T) bool) *T {
	for _, elem := range slice {
		if f(elem) {
			return &elem
		}
	}

	return nil
}
