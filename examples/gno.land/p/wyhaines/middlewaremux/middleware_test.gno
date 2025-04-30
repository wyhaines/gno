package middlewaremux

import (
	"testing"

	"gno.land/p/demo/uassert"
)

// TestMiddleware tests the middleware functionality
func TestMiddleware(t *testing.T) {
	t.Run("global middleware", func(t *testing.T) {
		router := NewRouter()

		// Add global middleware that adds a header
		router.Use(func(next HandlerFunc) HandlerFunc {
			return func(rw *ResponseWriter, req *Request) {
				rw.Write("Header\n")
				next(rw, req)
				rw.Write("\nFooter")
			}
		})

		// Add a simple route
		router.HandleFunc("hello", func(rw *ResponseWriter, req *Request) {
			rw.Write("Hello World")
		})

		// Render the route
		output := router.Render("hello")
		uassert.Equal(t, "Header\nHello World\nFooter", output)
	})

	t.Run("multiple middleware", func(t *testing.T) {
		router := NewRouter()

		// Add multiple middlewares to track execution order
		router.Use(
			func(next HandlerFunc) HandlerFunc {
				return func(rw *ResponseWriter, req *Request) {
					rw.Write("First In\n")
					next(rw, req)
					rw.Write("\nFirst Out")
				}
			},
			func(next HandlerFunc) HandlerFunc {
				return func(rw *ResponseWriter, req *Request) {
					rw.Write("Second In\n")
					next(rw, req)
					rw.Write("\nSecond Out")
				}
			},
		)

		// Add a simple route
		router.HandleFunc("test", func(rw *ResponseWriter, req *Request) {
			rw.Write("Handler")
		})

		// Render the route to test middleware execution order
		output := router.Render("test")
		expected := "First In\nSecond In\nHandler\nSecond Out\nFirst Out"
		uassert.Equal(t, expected, output)
	})

	t.Run("route groups and middleware", func(t *testing.T) {
		router := NewRouter()

		// Global middleware
		router.Use(func(next HandlerFunc) HandlerFunc {
			return func(rw *ResponseWriter, req *Request) {
				rw.Write("[Global]")
				next(rw, req)
			}
		})

		// Create an API route group with its own middleware
		api := router.Group("/api", func(next HandlerFunc) HandlerFunc {
			return func(rw *ResponseWriter, req *Request) {
				rw.Write("[API]")
				next(rw, req)
			}
		})

		// Create a nested users group with its own middleware
		users := api.Group("/users", func(next HandlerFunc) HandlerFunc {
			return func(rw *ResponseWriter, req *Request) {
				rw.Write("[Users]")
				next(rw, req)
			}
		})

		// Add routes at different levels
		router.HandleFunc("home", func(rw *ResponseWriter, req *Request) {
			rw.Write("Home")
		})

		api.HandleFunc("status", func(rw *ResponseWriter, req *Request) {
			rw.Write("API Status")
		})

		users.HandleFunc("{id}", func(rw *ResponseWriter, req *Request) {
			id := req.GetVar("id")
			rw.Write("User " + id)
		})

		// Test route at root level
		output := router.Render("home")
		uassert.Equal(t, "[Global]Home", output)

		// Test route in API group
		output = router.Render("api/status")
		uassert.Equal(t, "[Global][API]API Status", output)

		// Test route in nested users group
		output = router.Render("api/users/123")
		uassert.Equal(t, "[Global][API][Users]User 123", output)
	})

	t.Run("authentication middleware example", func(t *testing.T) {
		router := NewRouter()

		// Simple auth middleware
		authMiddleware := func(next HandlerFunc) HandlerFunc {
			return func(rw *ResponseWriter, req *Request) {
				// Check for auth token
				token := req.Query.Get("token")
				if token != "valid-token" {
					rw.Write("Unauthorized")
					return // Do not call next handler
				}
				next(rw, req)
			}
		}

		// Create admin group with auth middleware
		admin := router.Group("/admin", authMiddleware)

		// Add routes
		router.HandleFunc("public", func(rw *ResponseWriter, req *Request) {
			rw.Write("Public Route")
		})

		admin.HandleFunc("dashboard", func(rw *ResponseWriter, req *Request) {
			rw.Write("Admin Dashboard")
		})

		// Test public route (no auth needed)
		output := router.Render("public")
		uassert.Equal(t, "Public Route", output)

		// Test admin route without auth token
		output = router.Render("admin/dashboard")
		uassert.Equal(t, "Unauthorized", output)

		// Test admin route with valid auth token
		output = router.Render("admin/dashboard?token=valid-token")
		uassert.Equal(t, "Admin Dashboard", output)
	})
}
