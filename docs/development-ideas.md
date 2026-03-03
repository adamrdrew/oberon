# Oberon — Development Ideas

## Advantage Profile

| Constraint | Traditional AI | Oberon |
|---|---|---|
| Cost per query | $$ | **Free** |
| Parallel sessions | Expensive | **Unlimited** |
| Context window | 128K+ | **4,096 tokens** |
| Model capability | Very high | **Limited** |
| OS integration | Sandboxed/cloud | **Full Apple APIs** |
| Latency tolerance | Low | **Flexible** (on-device) |

The "unlimited free queries" angle is massively underexploited.

---

## 1. Multi-Session Orchestration ("Swarm of Small Models")

Since sessions cost nothing, use **multiple specialized sessions** instead of one general one:

- **Summarizer session** — Before stuffing search results into the main chat, run a separate session that distills results into a tight 200-token summary. Already doing this for web search; generalize it.
- **Classifier/router session** — A tiny session with no tools that classifies user intent: "is this a math question, a factual lookup, a creative request, a calendar task?" Then route to specialized handling.
- **Verification session** — After the main model answers, run a second session: "Is this answer consistent with these facts: [search results]?" Cheap self-check.
- **Instruction distillation** — For long user profiles or complex instructions, run a session that compresses them into the most token-efficient form before injecting into the main chat.

**The pattern**: Pipeline of cheap sessions, each with a narrow job, instead of asking one session to do everything.

---

## 2. Apple API "Superpowers" (Pre/Post Processing)

The model can't do math or code — but **Apple frameworks can**. Do the heavy lifting outside the model:

- **NaturalLanguage.framework** — Sentiment analysis, named entity recognition, language detection, tokenization, embedding similarity. All on-device, no model tokens spent.
- **Translation framework** — Full on-device translation. The model doesn't need to translate; just wrap input/output.
- **EventKit / Contacts / Reminders** — Read/write calendar, contacts, reminders. The model just needs to express intent; Swift code does the actual API call.
- **MapKit / CoreLocation** — Geocoding, nearby search, directions. Model says "find coffee near me"; code calls MapKit.
- **MusicKit / MediaPlayer** — "Play some jazz" becomes a MusicKit query.
- **NLEmbedding** — Semantic similarity without spending tokens. Could do retrieval over past conversations locally.
- **NSExpression / math parser** — Model says "calculate 15% of 230" and we eval it.

**The pattern**: The model becomes an **intent parser**, not the executor. Apple APIs are the hands.

---

## 3. Smart Tool Design (Maximize the 2-4 Remaining Slots)

Each tool should be a **Swiss army knife** — one tool definition that dispatches to many capabilities.

### Option A: `device_action` (unified system tool)
One tool that takes an `action` parameter with values like:
- `calculate` — math expressions
- `set_reminder` — title, date
- `set_timer` — duration
- `create_event` — title, date, time
- `get_weather` — location (WeatherKit)
- `get_location` — current location

One tool definition, many capabilities. Saves token budget.

### Option B: `knowledge_lookup` (structured retrieval)
A tool that queries specific knowledge backends:
- Wikipedia API (structured, reliable)
- Dictionary/thesaurus
- Unit conversion tables
- Curated fact store

### Option C: `smart_compose` (text processing)
Offloads tasks the model is bad at:
- Summarize clipboard contents (using a second session)
- Translate text (Translation framework)
- Fix grammar (separate session with narrow instructions)
- Format as bullet points / table / email

### Option D: `memory_store` / `memory_recall`
Persistent user knowledge the model can explicitly store and retrieve:
- "Remember that my wife's name is Sarah"
- Stored in SwiftData, retrieved via NLEmbedding similarity
- Injected into instructions when relevant

---

## 4. Context Window Hacks

- **Aggressive prompt compression** — Use a dedicated session to rewrite the last N messages into the shortest possible form before restoring a transcript.
- **Sliding window with summaries** — Keep only the last 2-3 exchanges verbatim, summarize everything else.
- **Dynamic tool loading** — Don't register all tools on every session. Use the classifier session to decide which 1-2 tools this query needs, and only register those. Saves hundreds of tokens in tool definitions.
- **Instruction caching** — If the user profile hasn't changed, pre-compute a token-minimal instruction string and reuse it.

---

## 5. Post-Processing Enrichment

After the model responds, enrich the output with no token cost:

- **Auto-link detection** — Find entities in the response and link them (Wikipedia, Maps, App Store)
- **Fact cards** — If the model mentions a place, person, or date, pull a structured card from an API
- **Code/math detection** — If the response contains something that looks like math or code, run it through an evaluator and append the result
- **Smart formatting** — Use NaturalLanguage to detect lists, comparisons, etc. and render them as rich SwiftUI (tables, charts)

---

## Recommended Tool Allocation

Given 2-4 remaining slots, priority order:

1. **`device_action`** — Unified system integration (calculator, reminders, calendar, timer, weather, location). Biggest bang for the buck.
2. **`memory`** — Store/recall user facts with semantic search. Makes the assistant feel personal over time.
3. **`knowledge_lookup`** — Structured data (Wikipedia, dictionary, unit conversion). More reliable than web search for factual queries.
4. *(optional)* **`text_transform`** — Translation, summarization, grammar fix via Apple APIs + secondary sessions.

Plus implement **dynamic tool loading** so we're only ever registering 2-3 tools per query based on a quick classifier pass.
