---
layout: post
title: "Building a Go API - Part 3: Adding Pet Management and POST Requests"
date: 2025-09-13 09:52:20
category: go
tags: [go, api, rest, backend, postgres, sql, database]
---

In the last article, we successfully connected our API to a real PostgreSQL database. With that foundation in place, we can now expand our application to handle more complex data: pets.

This article will cover the creation of a new `PetStore` interface and implementation, and we'll build new handlers to get and create pet records. This will be our first time handling a `POST` request, which introduces new challenges like decoding request bodies and validating data.

## Defining the Pet Model

First, we need to create the `Pet` and `CreatePetRequest` data structures in `internal/types/types.go`. The `Pet` struct will represent a complete pet record, including its `Breed` details, while `CreatePetRequest` will be used to decode the incoming JSON from a `POST` request.

```go
package types

import "time"

// Pet represents a pet in our system.
type Pet struct {
	ID    string    `json:"id"`
	Name  string    `json:"name"`
	Birth time.Time `json:"birth"`
	Breed Breed     `json:"breed"` // Embedded Breed struct
}

// CreatePetRequest is the structure for the POST request body.
type CreatePetRequest struct {
	Name    string `json:"name"`
	Birth   string `json:"birth"`
	BreedID string `json:"breed_id"`
}
```

Notice that `CreatePetRequest` has a `Birth` field of type `string`. This is a common practice when working with JSON APIs, as it allows us to handle and parse the date string manually, providing better error handling if the format is incorrect.

## Expanding the `Store` Layer

We'll define a new `PetStore` interface that includes methods for getting all pets, getting a pet by ID, and creating a new pet. This follows the same pattern we established for `BreedStore`.

```go
package store

import "time"
import "github.com/agugliotta/dog-app-bff/internal/types"

type PetStore interface {
    GetPets() ([]types.Pet, error)
    GetPetByID(id string) (*types.Pet, error)
    CreatePet(name string, birth time.Time, breedID string) (*types.Pet, error)
}
```

Next, we implement these methods in our `PostgresStore` (in `internal/store/postgres_store.go`). The `CreatePet` method is particularly important as it will handle inserting a new record into the database.

```go
// CreatePet inserts a new pet record into the database.
func (s *PostgresStore) CreatePet(name string, birth time.Time, breedID string) (*types.Pet, error) {
	query := `INSERT INTO pets (name, birth, breed_id) VALUES ($1, $2, $3) RETURNING id`

	var petID string
	err := s.db.QueryRow(query, name, birth, breedID).Scan(&petID)
	if err != nil {
		return nil, fmt.Errorf("error creating pet: %w", err)
	}

	// Now fetch the full pet record including breed details
	pet, err := s.GetPetByID(petID)
	if err != nil {
		return nil, fmt.Errorf("error fetching newly created pet: %w", err)
	}

	return pet, nil
}
```

## Creating the Pet Handler

This is where we'll introduce our first `POST` handler. We'll create a single `PetHandler` with a multiplexing method that delegates to different handlers based on the HTTP method (`GET` or `POST`). This is a common pattern when using `net/http.ServeMux`.

```go
package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"github.com/agugliotta/dog-app-bff/internal/types"
)

type PetHandler struct {
	petStore   store.PetStore
	breedStore store.BreedStore
}

func NewPetHandler(ps store.PetStore, bs store.BreedStore) *PetHandler {
	return &PetHandler{petStore: ps, breedStore: bs}
}

// PetsHandler is a multiplexing handler for pets.
func (h *PetHandler) PetsHandler(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		h.getPetsHandler(w, r)
	case http.MethodPost:
		h.createPetHandler(w, r)
	default:
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
	}
}

// createPetHandler handles the POST request to create a new pet.
func (h *PetHandler) createPetHandler(w http.ResponseWriter, r *http.Request) {
	// 1. Decode the request body
	var reqBody types.CreatePetRequest
	if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
		http.Error(w, "Error decoding the body of the request", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// 2. Validate the data
	birth, err := time.Parse("2006-01-02", reqBody.Birth)
	if err != nil {
		http.Error(w, "Bad date of birth format. Use YYYY-MM-DD", http.StatusBadRequest)
		return
	}

	// 3. Check if the breed exists before creating the pet
	if _, err := h.breedStore.GetBreedByID(reqBody.BreedID); err != nil {
		http.Error(w, "Error checking the breed", http.StatusBadRequest)
		return
	}

	// 4. Create the pet
	newPet, err := h.petStore.CreatePet(reqBody.Name, birth, reqBody.BreedID)
	if err != nil {
		http.Error(w, "Error creating pet", http.StatusInternalServerError)
		return
	}

	// 5. Send the success response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	if err := json.NewEncoder(w).Encode(newPet); err != nil {
		log.Printf("Error encoding response for created pet: %v", err)
	}
}
```

The `createPetHandler` illustrates a clean request lifecycle:
1.  **Decoding:** Reading the JSON body into our `CreatePetRequest` struct.
2.  **Validation:** Checking for valid data formats (like the birth date).
3.  **Business Logic:** Checking for the existence of the related breed.
4.  **Database Interaction:** Calling our `PetStore` to create the record.
5.  **Response:** Sending back a `201 Created` status code along with the new pet's data.

## Conclusion

We've successfully added pet management to our API. This article focused on handling `POST` requests, which required us to think about decoding request bodies and performing data validation. This hands-on experience demonstrated the full lifecycle of a RESTful API request.

In the next part, we'll dive deep into testing. We'll write unit and integration tests to ensure our handlers and store implementations are reliable, laying the groundwork for a robust CI/CD pipeline.

Stay tuned!

