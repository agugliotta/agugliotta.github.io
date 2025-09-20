---
layout: post
title: "Building a Go API - Part 4: Testing, CI, and a Working Makefile"
date: 2025-09-20 17:22:07
category: go
tags: [go, api, rest, backend, postgres, sql, database]
---

We've built a functional API, but how can we be sure it works as expected? The answer is rigorous testing and automation. This article will show you how to write comprehensive tests for your Go API and automate the entire build and test process with GitHub Actions.

This part will tie together everything we've built, ensuring our code is reliable and our development workflow is efficient.

## Testing Your Handlers with `httptest`

The standard Go library provides a powerful package called `httptest` that lets us simulate HTTP requests and responses. This is perfect for unit testing our handlers in isolation. We can use mocks for the `store` layer, as we learned in Part 1.

Here is an example of a test for our `CreatePetHandler`:

```go
package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/agugliotta/dog-app-bff/internal/store"
	"github.com/agugliotta/dog-app-bff/internal/types"
)

func TestCreatePetHandler(t *testing.T) {
	// Mocks to simulate the database
	breeds := []types.Breed{{ID: "b1", Name: "Breed1"}}
	petStore := &store.PetStoreMock{breeds: breeds}
	breedStore := &store.BreedStoreMock{breeds: breeds}
	handler := NewPetHandler(petStore, breedStore)

	t.Run("success", func(t *testing.T) {
		reqBody := types.CreatePetRequest{
			Name:    "Fido",
			Birth:   "2020-01-01",
			BreedID: "b1",
		}
		body, _ := json.Marshal(reqBody)
		req, _ := http.NewRequest("POST", "/api/v1/pets", bytes.NewReader(body))
		rec := httptest.NewRecorder()
		handler.PetsHandler(rec, req)

		if rec.Code != http.StatusCreated {
			t.Errorf("expected 201, got %d", rec.Code)
		}
		var got types.Pet
		if err := json.NewDecoder(rec.Body).Decode(&got); err != nil {
			t.Errorf("error decoding: %v", err)
		}
		if got.Name != "Fido" || got.Breed.ID != "b1" {
			t.Errorf("unexpected pet: %+v", got)
		}
	})

	t.Run("bad json", func(t *testing.T) {
		req, _ := http.NewRequest("POST", "/api/v1/pets", bytes.NewReader([]byte("not-json")))
		rec := httptest.NewRecorder()
		handler.PetsHandler(rec, req)

		if rec.Code != http.StatusBadRequest {
			t.Errorf("expected 400, got %d", rec.Code)
		}
	})
	// We would add more test cases for bad breed, bad date, etc.
}
```

This test shows how we can simulate a full request-response cycle and verify the behavior of our handler, including a successful creation and a failure due to bad input.

## Automating the Workflow with `Makefile`

Our `Makefile` is an indispensable tool for automating common tasks. It lets us run tests, build the application, and manage our Docker containers with simple commands.

```makefile
# Define variables
PROJECT_NAME := dog-app-bff
DOCKER_DB_CONTAINER := $(PROJECT_NAME)-postgres-test
DOCKER_DB_PASSWORD := mysecretpassword
DOCKER_DB_NAME := dog_app_db_test
DB_PORT := 5432
TEST_DB_CONN_STRING := "host=localhost port=$(DB_PORT) user=postgres password=$(DOCKER_DB_PASSWORD) dbname=$(DOCKER_DB_NAME) sslmode=disable"

.PHONY: test test-unit test-integration db-start db-stop db-setup-test

# Run all tests
test: test-unit test-integration

# Run unit tests only
test-unit:
	@go test -v ./internal/handlers/...

# Run integration tests, managing the DB automatically
test-integration: db-setup-test
	@trap 'make db-stop' EXIT; TEST_DB_CONN_STRING=$(TEST_DB_CONN_STRING) go test -v ./internal/store/...

db-setup-test: db-stop db-start
	@echo "Configuring the test database..."
	@sleep 2
	@docker exec -i $(DOCKER_DB_CONTAINER) psql -U postgres -d $(DOCKER_DB_NAME) -v ON_ERROR_STOP=1 <<EOF
	DROP TABLE IF EXISTS pets CASCADE;
	DROP TABLE IF EXISTS breeds CASCADE;
	-- SQL to create tables and insert test data
	EOF
```

This `Makefile` is a workhorse. The `test-integration` command is particularly clever: it automatically starts and configures our test database before running the tests and ensures the database is stopped afterward, even if the tests fail.

## Setting Up Continuous Integration with GitHub Actions

Now for the final piece of the puzzle: automating this process on every push and pull request. GitHub Actions is the perfect tool for this. The biggest challenge is replicating our local `Makefile` environment in the cloud.

We'll use GitHub Actions' `services` feature to spin up a PostgreSQL container and a series of `run` steps to set up the database and run our tests.

```yaml
name: Go

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

env:
  DOCKER_DB_PASSWORD: mysecretpassword
  DOCKER_DB_NAME: dog_app_db_test
  DB_PORT: 5432
  TEST_DB_CONN_STRING: "host=localhost port=$(DB_PORT) user=postgres password=$(DOCKER_DB_PASSWORD) dbname=$(DOCKER_DB_NAME) sslmode=disable"

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15-alpine
        env:
          POSTGRES_PASSWORD: ${{ env.DOCKER_DB_PASSWORD }}
          POSTGRES_DB: ${{ env.DOCKER_DB_NAME }}
        ports:
          - 5432:5432
    steps:
    - uses: actions/checkout@v4
    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.24'
    - name: Test - Unitarios
      run: go test -v ./internal/handlers/...
    - name: Setup test database
      env:
        PGPASSWORD: ${{ env.DOCKER_DB_PASSWORD }}
      run: |
        psql -h localhost -U postgres -d ${{ env.DOCKER_DB_NAME }} -v ON_ERROR_STOP=1 <<EOF
        DROP TABLE IF EXISTS pets CASCADE;
        DROP TABLE IF EXISTS breeds CASCADE;
        -- SQL to create tables and insert test data
        EOF
    - name: Test - Integración
      run: TEST_DB_CONN_STRING=$(TEST_DB_CONN_STRING) go test -v ./internal/store/...
```

The key learnings from this process were:
* Using `services` to create the database container.
* The `host` for `psql` and our Go tests must be `localhost` to connect to the service.
* Careful handling of environment variables to ensure they are passed correctly.
* Using a "here document" with `psql` to reliably execute a multi-line SQL script.

## Conclusion

We've now covered the complete lifecycle of a feature: from building the API to testing it and automating the entire process with GitHub Actions. This final piece provides the confidence and efficiency needed to develop software professionally.

In our final article, we'll wrap up the series by summarizing our journey and discussing potential next steps for the project.

Stay tuned!

