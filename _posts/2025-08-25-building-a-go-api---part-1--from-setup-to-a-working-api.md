---
layout: post
title: "Building a Go API - Part 1: From Setup to a Working API"
date: 2025-08-25 17:56:05
category: go
tags: [go, api, rest, backend]
---

Welcome to the first part of our journey to build a robust Go API! In this series, I'll share my experience, detailing the problems I encountered and the solutions I found along the way. We'll go from a blank project to a fully functional, tested, and deployed application.

In this first post, our goal is to lay the foundation for our API and build our first working endpoint for managing dog breeds, all without touching a real database.

## Project Initialization and Structure

The first step was to set up a new Go module. This command creates a `go.mod` file, which is essential for managing our dependencies.

```bash
go mod init github.com/agugliotta/dog-app-bff
```

Next, I established a clear directory structure based on common Go project conventions. This structure keeps our code organized and makes it easier for other developers to understand the project's layout.

```
dog-app-bff/
├── cmd/
│   └── api/
│       └── main.go         // The entry point to start the API server
├── internal/
│   ├── handlers/           // HTTP request handlers
│   ├── store/              // Data storage interfaces and implementations
│   └── types/              // Core data types and models
└── go.mod
└── go.sum
```

* **`cmd/api/`**: This directory contains the `main.go` file, our application's entry point.
* **`internal/`**: This is where all the application logic lives. The `internal` directory is not importable by external projects, which helps enforce good design principles.
* **`internal/handlers/`**: Houses the functions that handle HTTP requests.
* **`internal/store/`**: Contains the interfaces and implementations for interacting with our data layer (e.g., a database). This separation is key to a testable application.
* **`internal/types/`**: Defines our data structures, such as a `Breed` or `Pet`.

## Defining Our Data Model

To begin, I created the core data model for a dog breed in `internal/types/types.go`. This struct will be used to represent the data throughout our application.

```go
package types

type Breed struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Temperament string `json:"temperament"`
	Origin      string `json:"origin"`
}
```

The backticks (e.g., `` `json:"id"` ``) are Go struct tags. They tell the `json` package how to map the struct fields to JSON keys when we encode or decode data.

---

## Building the Data Layer (with a Mock)

A crucial concept in Go is using **interfaces** to define behavior. By creating a `BreedStore` interface, we can swap out the underlying data source (a mock, a real database, etc.) without changing our handler code.

### Defining the `Store` Interface

First, I created the `BreedStore` interface in `internal/store/store.go`.

```go
package store

import "github.com/agugliotta/dog-app-bff/internal/types"

type BreedStore interface {
    GetBreeds() ([]types.Breed, error)
    GetBreedByID(id string) (*types.Breed, error)
}
```

### Implementing a Mock Store

For this first part, I needed a way to test our handlers without connecting to a database. The solution was to create a `MockBreedStore` that implements the `BreedStore` interface using a slice of hardcoded breeds.

```go
package store

import (
    "errors"
    "github.com/agugliotta/dog-app-bff/internal/types"
)

var ErrNotFound = errors.New("not found")

type MockBreedStore struct{}

func NewMockBreedStore() *MockBreedStore {
    return &MockBreedStore{}
}

func (m *MockBreedStore) GetBreeds() ([]types.Breed, error) {
    // Return a list of predefined breeds
    return []types.Breed{
        {ID: "br1", Name: "Golden Retriever"},
        {ID: "br2", Name: "German Shepherd"},
    }, nil
}

func (m *MockBreedStore) GetBreedByID(id string) (*types.Breed, error) {
    breeds, _ := m.GetBreeds()
    for _, b := range breeds {
        if b.ID == id {
            return &b, nil
        }
    }
    return nil, ErrNotFound
}
```

This mock store is a perfect stand-in for a real database, allowing us to build and test our API handlers in isolation.

---

## Creating Handlers and Routes

With our types and mock store ready, the next step was to create the handler functions that process HTTP requests. I started by defining a `BreedHandler` struct that holds a reference to the `BreedStore`. This is a practice known as **dependency injection**, and it's what makes our code easy to test.

### The `BreedHandler` and its Methods

In `internal/handlers/breeds_handler.go`, I defined the handler and a method to get all breeds.

```go
package handlers

import (
    "encoding/json"
    "net/http"
    "github.com/agugliotta/dog-app-bff/internal/store"
)

type BreedHandler struct {
    breedStore store.BreedStore
}

func NewBreedHandler(bs store.BreedStore) *BreedHandler {
    return &BreedHandler{
        breedStore: bs,
    }
}

func (h *BreedHandler) GetBreedsHandler(w http.ResponseWriter, r *http.Request) {
    breeds, err := h.breedStore.GetBreeds()
    if err != nil {
        http.Error(w, "Error fetching breeds", http.StatusInternalServerError)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(breeds)
}
```

### The Router and `main.go`

Finally, I wired everything up in `cmd/api/main.go`. I created an instance of our `MockBreedStore`, injected it into the `BreedHandler`, and registered the handler to a route using Go's standard library `http.ServeMux`.

```go
package main

import (
    "log"
    "net/http"
    "github.com/agugliotta/dog-app-bff/internal/handlers"
    "github.com/agugliotta/dog-app-bff/internal/store"
)

func main() {
    mux := http.NewServeMux()

    // Dependency Injection: Inject the mock store into the handler
    breedStore := store.NewMockBreedStore()
    breedHandler := handlers.NewBreedHandler(breedStore)

    // Register our handler to the route
    mux.HandleFunc("/api/v1/breeds", breedHandler.GetBreedsHandler)

    log.Println("Starting server on :8080")
    if err := http.ListenAndServe(":8080", mux); err != nil {
        log.Fatalf("could not start server: %v", err)
    }
}
```

With this, we had a fully functional API endpoint. Running the application and hitting `http://localhost:8080/api/v1/breeds` with a tool like `curl` returned a JSON array of our mock breeds.

## Conclusion

This first stage was critical. We established a clean, maintainable project structure and implemented our first API endpoint using a mock data store. This approach allowed us to rapidly develop and test the API's logic without the added complexity of a real database.

In the next part, we'll replace our `MockBreedStore` with a real `PostgresStore` and learn how to use Docker to run our database locally.

Stay tuned!

