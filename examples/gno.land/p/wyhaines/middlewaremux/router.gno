package middlewaremux

import (
	"net/url"
	"strings"
)

// Router handles the routing and rendering logic.
type Router struct {
	routes          []Handler
	NotFoundHandler NotFoundHandler
	middlewares     []Middleware // Global middlewares that apply to all routes
}

// NewRouter creates a new Router instance.
func NewRouter() *Router {
	return &Router{
		routes:          make([]Handler, 0),
		NotFoundHandler: defaultNotFoundHandler,
		middlewares:     make([]Middleware, 0),
	}
}

// Use adds middleware to the router that will be executed for all routes
func (r *Router) Use(middlewares ...Middleware) {
	r.middlewares = append(r.middlewares, middlewares...)
}

// Render renders the output for the given path using the registered route handler.
func (r *Router) Render(reqPath string) string {
	clearPath, rawQuery, _ := strings.Cut(reqPath, "?")
	query, _ := url.ParseQuery(rawQuery)
	reqParts := strings.Split(clearPath, "/")

	for _, route := range r.routes {
		patParts := strings.Split(route.Pattern, "/")
		wildcard := false
		for _, part := range patParts {
			if part == "*" {
				wildcard = true
				break
			}
		}
		if !wildcard && len(patParts) != len(reqParts) {
			continue
		}

		match := true
		for i := 0; i < len(patParts); i++ {
			patPart := patParts[i]
			reqPart := reqParts[i]

			if patPart == "*" {
				break
			}
			if strings.HasPrefix(patPart, "{") && strings.HasSuffix(patPart, "}") {
				continue
			}
			if patPart != reqPart {
				match = false
				break
			}
		}
		if match {
			req := &Request{
				Path:        clearPath,
				RawPath:     reqPath,
				HandlerPath: route.Pattern,
				Query:       query,
			}
			res := &ResponseWriter{}

			// Apply middlewares to the handler function
			handlerWithMiddleware := Chain(route.Fn, r.middlewares...)
			handlerWithMiddleware(res, req)
			return res.Output()
		}
	}

	// not found
	req := &Request{Path: reqPath, Query: query}
	res := &ResponseWriter{}
	r.NotFoundHandler(res, req)
	return res.Output()
}

// HandleFunc registers a route and its handler function.
func (r *Router) HandleFunc(pattern string, fn HandlerFunc) {
	route := Handler{Pattern: pattern, Fn: fn}
	r.routes = append(r.routes, route)
}

// HandleErrFunc registers a route and its error handler function.
func (r *Router) HandleErrFunc(pattern string, fn ErrHandlerFunc) {
	// Convert ErrHandlerFunc to regular HandlerFunc
	handler := func(res *ResponseWriter, req *Request) {
		if err := fn(res, req); err != nil {
			res.Write("Error: " + err.Error())
		}
	}

	r.HandleFunc(pattern, handler)
}

// SetNotFoundHandler sets custom message for 404 defaultNotFoundHandler.
func (r *Router) SetNotFoundHandler(handler NotFoundHandler) {
	r.NotFoundHandler = handler
}

// Group creates a new RouteGroup with the specified path prefix and optional middlewares
func (r *Router) Group(pathPrefix string, middlewares ...Middleware) *RouteGroup {
	return &RouteGroup{
		router:      r,
		pathPrefix:  pathPrefix,
		middlewares: middlewares,
	}
}

// RouteGroup represents a group of routes with a common path prefix and middlewares
type RouteGroup struct {
	router      *Router
	pathPrefix  string
	middlewares []Middleware
}

// Use adds middlewares to the route group
func (g *RouteGroup) Use(middlewares ...Middleware) {
	g.middlewares = append(g.middlewares, middlewares...)
}

// HandleFunc registers a route with the group's path prefix and applies the group's middlewares
func (g *RouteGroup) HandleFunc(pattern string, fn HandlerFunc) {
	// Apply group-specific middlewares
	handlerWithMiddleware := Chain(fn, g.middlewares...)

	// Register the route with the combined path
	fullPattern := g.pathPrefix
	if !strings.HasSuffix(fullPattern, "/") && !strings.HasPrefix(pattern, "/") && pattern != "" {
		fullPattern += "/"
	}
	if strings.HasPrefix(pattern, "/") && strings.HasSuffix(g.pathPrefix, "/") {
		pattern = pattern[1:]
	}
	fullPattern += pattern

	g.router.HandleFunc(fullPattern, handlerWithMiddleware)
}

// HandleErrFunc registers an error handler route with the group
func (g *RouteGroup) HandleErrFunc(pattern string, fn ErrHandlerFunc) {
	// Convert ErrHandlerFunc to regular HandlerFunc
	handler := func(res *ResponseWriter, req *Request) {
		if err := fn(res, req); err != nil {
			res.Write("Error: " + err.Error())
		}
	}

	g.HandleFunc(pattern, handler)
}

// Group creates a nested route group
func (g *RouteGroup) Group(pathPrefix string, middlewares ...Middleware) *RouteGroup {
	combinedPrefix := g.pathPrefix
	if !strings.HasSuffix(combinedPrefix, "/") && !strings.HasPrefix(pathPrefix, "/") && pathPrefix != "" {
		combinedPrefix += "/"
	}
	if strings.HasPrefix(pathPrefix, "/") && strings.HasSuffix(g.pathPrefix, "/") {
		pathPrefix = pathPrefix[1:]
	}
	combinedPrefix += pathPrefix

	// Combine middlewares (parent group middlewares + new middlewares)
	combinedMiddlewares := append(g.middlewares, middlewares...)

	return &RouteGroup{
		router:      g.router,
		pathPrefix:  combinedPrefix,
		middlewares: combinedMiddlewares,
	}
}
