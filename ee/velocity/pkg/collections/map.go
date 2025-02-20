package collections

func Map[T any, V any](slice []T, f func(T) V) []V {
	result := make([]V, len(slice))
	for i, v := range slice {
		result[i] = f(v)
	}
	return result
}

func Reduce[T any, V any](slice []T, initial V, f func(V, T) V) V {
	for _, v := range slice {
		initial = f(initial, v)
	}
	return initial
}
