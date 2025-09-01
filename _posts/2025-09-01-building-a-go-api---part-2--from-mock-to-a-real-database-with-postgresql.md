---
layout: post
title: "Building a Go API - Part 2: From Mock to a Real Database with PostgreSQL"
date: 2025-09-01 10:44:37
category: go
tags: [go, api, rest, backend, postgres, sql, database]
---

Welcome back! In the previous post, we built a foundational Go API with a clean structure and a mock data store. We proved our handlers and routing worked in isolation. But a real-world application needs a real database.

In this article, we will replace our `MockBreedStore` with a `PostgresStore`. We'll set up a PostgreSQL database locally using Docker and write the `store` implementation to connect to it, a crucial step toward building a robust and production-ready service.

## Setting Up PostgreSQL with Docker

To avoid the hassle of local database installation, we'll use Docker. This makes our development environment consistent and portable. We'll use a `Makefile` to manage the Docker commands, a practice that simplifies common development tasks.

Here's the relevant section from our `Makefile`:

```makefile
# Define variables for the database
DOCKER_DB_CONTAINER := $(PROJECT_NAME)-postgres-dev
DOCKER_DB_PASSWORD := mysecretpassword
DOCKER_DB_NAME := dog_app_db_dev
DB_PORT := 5432
DEV_DB_CONN_STRING := "host=localhost port=$(DB_PORT) user=postgres password=$(DOCKER_DB_PASSWORD) dbname=$(DOCKER_DB_NAME) sslmode=disable"

# Commands to start and stop the database
db-start:
	@echo "Starting PostgreSQL container..."
	@docker run --name $(DOCKER_DB_CONTAINER) \
        -e POSTGRES_PASSWORD=$(DOCKER_DB_PASSWORD) \
        -e POSTGRES_DB=$(DOCKER_DB_NAME) \
        -p $(DB_PORT):5432 \
        -d postgres:latest
	@echo "Waiting for PostgreSQL to be ready..."
	@sleep 5
	@echo "PostgreSQL container started."

db-stop:
	@echo "Stopping PostgreSQL container..."
	@docker stop $(DOCKER_DB_CONTAINER) > /dev/null 2>&1 || true
	@docker rm $(DOCKER_DB_CONTAINER) > /dev/null 2>&1 || true
	@echo "PostgreSQL container stopped and removed."
```

With these commands, we can easily start our database with `make db-start` and stop it with `make db-stop`.

## Implementing the `PostgresStore`

Next, we'll create the `PostgresStore` in `internal/store/postgres_store.go`. This struct will implement the `BreedStore` interface we defined earlier, allowing us to seamlessly swap out the mock store.

### The Connection Logic

First, we need a way to connect to the database. We'll add a constructor function, `NewPostgresStore`, that takes the database connection string and returns a `PostgresStore` instance.

```go
package store

import (
	"database/sql"
	"fmt"
	_ "github.com/lib/pq" // PostgreSQL driver
)

// PostgresStore implements the BreedStore interface using a PostgreSQL database.
type PostgresStore struct {
	db *sql.DB
}

func NewPostgresStore(connStr string) (*PostgresStore, error) {
	db, err := sql.Open("postgres", connStr)
	if err != nil {
		return nil, fmt.Errorf("could not connect to database: %w", err)
	}
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	// We'll add a function here to set up the tables for development
	return &PostgresStore{db: db}, nil
}
```

### Implementing `GetBreeds` and `GetBreedByID`

Now we'll implement the methods from the `BreedStore` interface. We use `database/sql` to query the database and map the results to our `types.Breed` structs.

```go
// GetBreeds retrieves all breeds from the database.
func (s *PostgresStore) GetBreeds() ([]types.Breed, error) {
    rows, err := s.db.Query("SELECT id, name, temperament, origin FROM breeds")
    if err != nil {
        return nil, fmt.Errorf("error querying breeds: %w", err)
    }
    defer rows.Close()

    var breeds []types.Breed
    for rows.Next() {
        var b types.Breed
        if err := rows.Scan(&b.ID, &b.Name, &b.Temperament, &b.Origin); err != nil {
            return nil, fmt.Errorf("error scanning breed row: %w", err)
        }
        breeds = append(breeds, b)
    }

    return breeds, nil
}

// GetBreedByID retrieves a single breed by its ID.
func (s *PostgresStore) GetBreedByID(id string) (*types.Breed, error) {
    var b types.Breed
    row := s.db.QueryRow("SELECT id, name, temperament, origin FROM breeds WHERE id = $1", id)
    if err := row.Scan(&b.ID, &b.Name, &b.Temperament, &b.Origin); err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, ErrNotFound
        }
        return nil, fmt.Errorf("error scanning breed: %w", err)
    }
    return &b, nil
}
```

## Connecting the Real Store to the Handler

The final step is to update our `main.go` to use the `PostgresStore` instead of the mock. This is where the power of dependency injection shines. We simply change which store implementation we inject into our handler.

```go
package main

import (
	"log"
	"net/http"
	"os"
	"github.com/agugliotta/dog-app-bff/internal/handlers"
	"github.com/agugliotta/dog-app-bff/internal/store"
)

func main() {
	// The database connection string is now an environment variable
	connStr := os.Getenv("DEV_DB_CONN_STRING")
	if connStr == "" {
		log.Fatal("DEV_DB_CONN_STRING environment variable is not set")
	}

	// Connect to the real PostgreSQL database
	postgresStore, err := store.NewPostgresStore(connStr)
	if err != nil {
		log.Fatalf("failed to create postgres store: %v", err)
	}

	mux := http.NewServeMux()
	// Inject the PostgresStore into the handler
	breedHandler := handlers.NewBreedHandler(postgresStore)
	
	mux.HandleFunc("/api/v1/breeds", breedHandler.GetBreedsHandler)

	log.Println("Starting server on :8080")
	if err := http.ListenAndServe(":8080", mux); err != nil {
		log.Fatalf("could not start server: %v", err)
	}
}
```

To run this, you'll need to set the `DEV_DB_CONN_STRING` environment variable. Our `Makefile` can handle this for us:

```makefile
run: build
	@echo "Running Go application..."
	@DEV_DB_CONN_STRING=$(DEV_DB_CONN_STRING) go run ./cmd/api/main.go
```

Now, running `make run` will start our API and connect it to the real PostgreSQL database.

## Conclusion

We've successfully moved from a mock data store to a real database. This process highlighted the importance of clean architecture with interfaces, which made it trivial to switch implementations. We also learned how to use Docker to manage our database and a `Makefile` to simplify our workflow.

In the next part, we'll expand our API to include pet management, adding more types and endpoints, including our first `POST` request.

Stay tuned!

