# Middleware System for Gno.land's Mux Package

## Overview

The middleware system in the `mux` package provides a powerful way to add cross-cutting functionality to your Gno.land applications. Middleware functions wrap handlers and can execute code before and after the handler, allowing for behavior like logging, authentication, rate limiting, and more. This package extends gno.land/p/demo/mux to provide integrated middleware support, and it is written to integrate well with the `gno.land/p/wyhaines/upgradeable` package, as well, enabling support for sophisticated upgradeability patterns.

## How Middleware Works

A middleware is a function that takes a handler and returns a new handler that does something additional. The middleware pattern follows this signature:

```go
type Middleware func(HandlerFunc) HandlerFunc
```

Where `HandlerFunc` is defined as:

```go
type HandlerFunc func(*ResponseWriter, *Request)
```

When a request is received, the middleware chain is executed in the order they were registered, with each middleware potentially calling the next one in the chain. This creates a "pipeline" that the request flows through before reaching your handler.

## Using Middleware

### Global Middleware

To apply middleware to all routes in your application:

```go
router := middlewaremuxNewRouter()

// Add global middleware
router.Use(LoggingMiddleware(), AuthMiddleware())

// Define routes
router.HandleFunc("home", HomeHandler)
```

### Route Group Middleware

You can apply middleware to specific groups of routes:

```go
// Create an authenticated API group
apiGroup := router.Group("/api", AuthMiddleware())

// All routes in this group will require authentication
apiGroup.HandleFunc("users", ListUsersHandler)
apiGroup.HandleFunc("users/{id}", GetUserHandler)
```

### Nested Groups

You can also create nested groups with additional middleware:

```go
// Admin routes require both authentication and admin authorization
adminGroup := apiGroup.Group("/admin", AdminMiddleware())
adminGroup.HandleFunc("dashboard", DashboardHandler)
```

## Creating Custom Middleware

Creating your own middleware is straightforward:

```go
func LoggingMiddleware() middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            // Do something before calling the next handler
            std.Emit("RequestStarted", "path", req.Path)
            
            // Call the next handler in the chain
            next(rw, req)
            
            // Do something after the handler has executed
            std.Emit("RequestCompleted", "path", req.Path)
        }
    }
}
```

## Middleware Execution Order

Middleware execution follows a "Russian doll" model:

1. Middleware are executed in the order they are added to the router or group
2. Each middleware can decide whether to call the next handler in the chain
3. After the innermost handler completes, the middleware stack "unwinds" in reverse order

For example, with middleware A, B, and C:

```
A (before) -> B (before) -> C (before) -> Handler -> C (after) -> B (after) -> A (after)
```

## Combining with Upgradeable Package

The middleware system works seamlessly with the `upgradeable` package, allowing you to:

1. Define upgradeable route handlers
2. Apply middleware to routes that use upgradeable functions
3. Upgrade handler implementations without changing middleware configuration

Example:

```go
// Define an upgradeable handler
profileHandler := upgradeable.NewStringFuncHolder(
    Registry,
    "profile_handler",
    RenderProfileV1,
)

// Create a route group with auth middleware
userRoutes := router.Group("/users", AuthMiddleware())

// Register the route using the upgradeable handler
userRoutes.HandleFunc("{id}", func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
    userId := req.GetVar("id")
    handler := profileHandler.Get()
    result := handler(userId)
    rw.Write(result)
})
```

## Common Middleware Patterns

### Authentication

```go
func AuthMiddleware() middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            // Check for authentication token
            token := req.Query.Get("token")
            if !isValidToken(token) {
                rw.Write("Unauthorized")
                return // Don't call next handler
            }
            next(rw, req)
        }
    }
}
```

### Rate Limiting

```go
func RateLimitMiddleware(limit int) middlewaremuxMiddleware {
    requestCount := 0 // In a real implementation, use persistent storage
    
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            requestCount++
            if requestCount > limit {
                rw.Write("Rate limit exceeded")
                return
            }
            next(rw, req)
        }
    }
}
```

### Logging

```go
func LoggingMiddleware() middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            // Log request start
            std.Emit("Request", "path", req.Path)
            
            // Call the next handler
            next(rw, req)
            
            // Log request completion
            std.Emit("RequestComplete", "path", req.Path)
        }
    }
}
```

### Access Control

```go
func AccessControlMiddleware(allowedAddresses ...std.Address) middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            caller := std.OriginCaller()
            
            allowed := false
            for _, addr := range allowedAddresses {
                if caller == addr {
                    allowed = true
                    break
                }
            }
            
            if !allowed {
                rw.Write("Access denied")
                return
            }
            
            next(rw, req)
        }
    }
}
```

## Best Practices

### 1. Keep Middleware Focused

Each middleware should have a single responsibility. This makes your middleware more reusable and easier to test.

### 2. Consider Short-Circuiting

Some middleware (like authentication) should short-circuit the request pipeline if certain conditions aren't met. Don't call `next(rw, req)` if you want to stop processing.

### 3. Use Middleware for Cross-Cutting Concerns

Good candidates for middleware include:
- Logging
- Authentication/Authorization
- Rate limiting
- Error handling
- Request/response transformation
- Metrics collection

### 4. Order Matters

Consider the order of your middleware carefully. For example:
- Logging middleware should typically be first to capture all requests
- Authentication should come before authorization
- Error handling middleware should wrap other middleware that might panic

### 5. Group Related Routes

Use route groups to apply specific middleware to related routes, keeping your routing logic clean and organized.

## Integrating with Upgradeable Functions

The middleware system works particularly well with the upgradeable package, allowing you to evolve your application while maintaining consistent cross-cutting concerns.

```go
// Define an upgradeable function
var userServiceFn = upgradeable.NewFunctionHolder(
    Registry,
    "get_user_service",
    GetUserServiceV1
)

// Create middleware that uses the upgradeable function
func UserServiceMiddleware() middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            // Get the current implementation of the service
            getUserService := userServiceFn.Get().(func() UserService)
            service := getUserService()
            
            // Use the service
            if !service.IsValidUser(req.GetVar("user")) {
                rw.Write("Invalid user")
                return
            }
            
            next(rw, req)
        }
    }
}
```

This pattern allows you to upgrade the service implementation without changing the middleware.

## Advanced Patterns

### Middleware Factory with Configuration

```go
func WithConfig(config Config) middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            // Use configuration values
            if !config.IsEnabled {
                next(rw, req)
                return
            }
            
            // Apply configured behavior
            rw.Write(config.HeaderText)
            next(rw, req)
            rw.Write(config.FooterText)
        }
    }
}
```

### Request Context Enrichment

In a full HTTP implementation, you'd use `context.WithValue`. For this simplified version:

```go
func WithUser() middlewaremuxMiddleware {
    return func(next middlewaremuxHandlerFunc) middlewaremuxHandlerFunc {
        return func(rw *middlewaremuxResponseWriter, req *middlewaremuxRequest) {
            userId := req.GetVar("user_id")
            // In a real implementation, you'd add the user to a context
            // For now, we'll just emit an event
            std.Emit("UserContext", "user_id", userId)
            next(rw, req)
        }
    }
}
```

## Conclusion

The middleware system provides a flexible way to add cross-cutting functionality to your Gno.land applications. By combining it with the upgradeable package, you can create applications that evolve over time while maintaining consistent behavior across routes.
