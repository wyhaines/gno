package middlewaremux

// Middleware represents a function that wraps a handler to provide additional functionality.
// It takes a handler and returns a new handler that performs some logic before and/or after
// calling the original handler.
type Middleware func(HandlerFunc) HandlerFunc

// Chain creates a new handler by applying middlewares to a handler in reverse order.
// The first middleware in the slice is the outermost middleware (it is executed first
// on the way in, and last on the way out).
func Chain(h HandlerFunc, middlewares ...Middleware) HandlerFunc {
	// Apply middlewares in reverse order
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}
