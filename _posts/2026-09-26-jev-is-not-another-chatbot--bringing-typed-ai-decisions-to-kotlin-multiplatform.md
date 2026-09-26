---
layout: post
title: "Jev Is Not Another Chatbot: Bringing Typed AI Decisions to Kotlin Multiplatform"
date: 2026-09-26 08:39:22
category: ai
tags: [jev, kotlin, kotlin-multiplatform, kmp, ai, ktor, sdk]
---

For the last few years, most AI integrations have followed the same pattern: send a prompt, get some text back, and then write increasingly nervous code to figure out what the model actually meant.

That works when the goal is to write an email or summarize a document. It feels much less natural when the application only needs to answer a smaller question:

* Which queue should receive this support ticket?
* How urgent is this incident?
* Is this transaction suspicious enough to require a review?

I recently discovered [Jev](https://typesafe.ai), TypeSafe's System One model, and the idea immediately clicked with me. Jev does not try to have a conversation or generate a beautiful paragraph. It makes a structured decision and returns probabilities that normal application code can use.

The problem was that I wanted to experiment with it from Kotlin Multiplatform, and there was no small KMP client that I could drop into shared code. So I built one.

## Decisions, Not Strings

The most interesting thing about Jev is its deliberately limited output. Instead of asking a general-purpose model to return JSON and hoping it respects the schema, Jev exposes three decision primitives:

* **`choice`** selects one option from a list and returns the probability distribution and confidence.
* **`score`** places the state on an ordered semantic scale.
* **`noul`** returns the probability that a yes-or-no statement is true.

That small surface is the point. A support-routing service does not need an essay about why a ticket looks like a billing issue. It needs something it can put into a `when` expression.

Imagine this state:

```text
The customer says they were charged twice and nobody has replied for three days.
```

One application might use `choice` to route it to billing, `score` to estimate urgency, and `noul` to decide whether a human should review it immediately. The model handles the fuzzy semantic judgment; the program still owns the workflow.

That separation is what attracted me. Jev is not a replacement for a general LLM. It is closer to a smart probabilistic branch in the places where a hard-coded `if` statement cannot understand human language.

## Why Kotlin Multiplatform?

If the decision logic is part of the product rather than the UI, I want to write it once.

The SDK lives in `commonMain` and uses Ktor Client with `kotlinx.serialization`. The same client API can therefore be shared by an Android app, an iOS app, or a JVM service. The project currently configures Android, JVM, iOS ARM64, iOS Simulator ARM64, and iOS x64 targets.

The public API starts with a value class for the key:

```kotlin
val apiKey = ApiKey("jev_live_your_api_key_here")
val client = JevClient(apiKey)
```

Using `ApiKey` instead of a raw `String` is a small decision, but I like what it buys: a blank key fails early, and an unrelated string cannot be passed accidentally just because the types happen to match.

The library also uses Kotlin's explicit API mode. Public visibility is intentional, which matters for a library that I expect other projects—and multiple platforms—to compile against.

## A Probabilistic Boolean

`noul` was the primitive that first changed how I thought about the API. It does not return a Boolean. It returns the probability that a statement is true.

```kotlin
val probability = client.evaluateNoul(
    state = "The user is attempting to checkout with an empty cart.",
    statement = "The user will successfully complete the purchase."
)
```

That distinction matters. A result near `0.5` does not mean "sort of true." It means the model is uncertain. The application decides what that uncertainty means.

For simple cases, the SDK includes a convenience method with an explicit threshold:

```kotlin
val canCheckout = client.evaluateNoulAsBoolean(
    state = "The user is attempting to checkout with an empty cart.",
    statement = "The user has items in their cart.",
    threshold = 0.7
)
```

In a real system, I would probably use two thresholds: automatically continue above the high threshold, reject below the low one, and send the uncertain middle to another model or a human. The important part is that the policy stays visible in my code.

## Routing with `choice`

For a closed set of actions, `choice` maps naturally to Kotlin:

```kotlin
val decision = client.evaluateChoice(
    state = "The user entered an invalid password three times.",
    optionsWithDescriptions = mapOf(
        "lock" to "Lock the account to prevent unauthorized access",
        "recover" to "Offer the account recovery flow",
        "ignore" to "Take no action"
    )
)

when (decision.chosenOption) {
    "lock" -> lockAccount()
    "recover" -> showRecovery()
    "ignore" -> continueNormally()
}
```

The winning option is useful, but I did not want the wrapper to hide the rest of the response. `JevChoiceResponse` also exposes the probabilities and confidence, because `lock` at `0.91` is operationally different from `lock` winning a nearly even race.

## Scoring Against a Rubric

The third primitive is `score`. It is for ordered levels rather than unrelated categories:

```kotlin
val urgency = client.evaluateScore(
    state = "The production API is returning errors for every checkout.",
    criteriaLevels = listOf(
        "No customer impact",
        "Minor degradation with a workaround",
        "Major degradation affecting many customers",
        "Complete outage requiring immediate response"
    )
)
```

The descriptions matter more than the numbers. "Severity from 1 to 4" leaves a lot to interpretation; a real rubric tells the model—and the humans reading the code—what each part of the scale means.

## The Boring Parts Still Matter

Wrapping three endpoints sounds easy until the failure paths arrive.

The client maps authentication failures, rate limiting, client errors, server errors, and service overload into a small exception hierarchy:

```kotlin
try {
    val score = client.evaluateScore(state, levels)
} catch (e: JevUnauthorizedException) {
    // Invalid or missing API key
} catch (e: JevRateLimitException) {
    // Back off or queue the work
} catch (e: JevServerException) {
    // Retry according to the application's policy
}
```

It also configures timeouts, ignores unknown response fields, and keeps the HTTP client injectable. None of this is the exciting part of a new AI technology, but it is the difference between an interesting demo and a library that can grow into something useful.

## Trying the SDK

The project is published through JitPack. Add the repository:

```kotlin
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}
```

Then add the current release to `commonMain`:

```kotlin
kotlin {
    sourceSets {
        commonMain.dependencies {
            implementation("com.github.agugliotta:jev-kmp:v1.1.0")
        }
    }
}
```

The source, examples, and installation instructions are in [agugliotta/jev-kmp](https://github.com/agugliotta/jev-kmp).

One important note: this is an **unofficial community SDK**. It is not endorsed, certified, sponsored by, or affiliated with TypeSafe or System One AI. Jev itself is also very new, so I expect its API and this wrapper to evolve.

## What Comes Next

The first version covers the core flow, but there is plenty I want to improve.

The current convenience methods send one question at a time even though the System One API can evaluate multiple typed questions against the same state. A batch API would be a natural next step. I also want stronger integration tests around mocked HTTP responses, better lifecycle control for the underlying Ktor client, and more complete examples for iOS.

There is also a larger architectural question: where should these decisions run? Putting an API key directly in a distributed mobile app is not a good production design. For a real application, I would normally keep the credential on a backend and expose only the product-specific decision operation to the client. KMP is still valuable there because the same library can power JVM backend code and shared prototypes, but the security boundary must remain explicit.

## Final Thoughts

The current AI conversation is dominated by models that can generate more: more text, more code, more images, more steps. Jev is interesting because it chooses to do less.

It takes a piece of state, answers a narrowly defined question, and gives control back to the application. No prose to parse. No pretend certainty hidden inside a confident sentence. Just a typed result, a probability, and a decision that the rest of the system can inspect.

That feels like a useful missing layer between traditional deterministic code and a general-purpose reasoning model.

If you are working with Kotlin Multiplatform, take the SDK for a spin and let me know where the API feels natural—or where it gets in your way. The project is early, and this is exactly the moment when real use cases can shape it.

