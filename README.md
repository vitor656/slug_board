# SlugBoard

A real-time, no-signup Kanban board that's created the moment you visit its URL.

Visit `/board/anything`, and a fresh board is either loaded or created on the spot. Share the link with anyone — no login, no setup — and you're both looking at (and editing) the exact same board, live.

---

## What it does

- **Boards are just URLs.** `/board/team-standup`, `/board/project-x`, `/board/whatever-you-type` — each slug maps to its own isolated board. Visit an existing slug and it loads; visit a new one and it's created automatically.
- **No accounts, no database setup.** Enter a display name when you join — that's the only "auth" there is.
- **Real-time by default.** Every change (a card added, moved, edited, a column renamed) is broadcast instantly to everyone viewing that board. No refresh, ever.
- **Presence.** See who else is currently looking at the board, represented by colored avatar initials in the header — added and removed automatically as people join or close the tab.
- **Drag-and-drop.** Move cards between columns with the mouse, built on the browser's native HTML5 drag-and-drop API (no external JS library).
- **Full CRUD on cards and columns.** Add, edit, and delete both, with confirmation prompts before anything destructive.
- **Responsive.** Desktop shows all columns side by side; mobile switches to a horizontally-swipeable, snap-scrolling layout.

## Why it exists

This is a portfolio project built to explore a specific slice of the Elixir/Phoenix ecosystem: **stateful, real-time, multi-user systems without leaning on a database for runtime state.** Instead of persisting everything to Postgres and querying it on every render, each board is a living process in memory — which is a very different (and very Elixir-native) way to think about application state.

## How it's built

No traditional database. Each board's state — its columns and cards — lives entirely in an Elixir process, kept alive for as long as the board exists.

```
Visitor requests /board/:slug
        │
        ▼
Registry: is a process already registered under this slug?
   │                              │
   no                            yes
   │                              │
   ▼                              ▼
DynamicSupervisor starts    Reuse the existing
a new BoardServer            BoardServer's PID
   │                              │
   └──────────────┬───────────────┘
                   ▼
     LiveView subscribes to `board:<slug>` on PubSub
                   │
                   ▼
   Every mutation (add/move/edit/delete) goes through
   the BoardServer, which updates its state and
   broadcasts the new state to every subscriber
```

**Core building blocks:**

| Piece                       | Role                                                                                      |
| --------------------------- | ----------------------------------------------------------------------------------------- |
| `Registry`                  | Maps a board's slug to its process PID — the "phone book" for boards                      |
| `DynamicSupervisor`         | Starts a `BoardServer` process on demand, the first time a slug is visited                |
| `GenServer` (`BoardServer`) | Owns a single board's state; serializes every mutation so concurrent edits never race     |
| `Phoenix.PubSub`            | Broadcasts state changes to every connected client watching that board                    |
| `Phoenix.Presence`          | Tracks who's currently viewing a board, with automatic cleanup on disconnect              |
| `DETS`                      | Persists each board's state to a local file, so a server restart doesn't wipe every board |

A quick note on that last point, since it's a distinction that shaped the whole design: **process supervision restores availability, not data.** If a `BoardServer` crashes, its supervisor can restart it — but the restarted process starts with a blank slate unless it explicitly reloads its state from somewhere durable. That's what DETS is for here: a lightweight, file-based, zero-infrastructure way to make board state survive restarts without paying for (or operating) a hosted database.

## Tech stack

- **Elixir / Phoenix / Phoenix LiveView** — application and real-time UI
- **Tailwind CSS v4** — styling, via `@theme` design tokens
- **Native HTML5 Drag and Drop API**, wired up through small Phoenix LiveView JS hooks
- **DETS** — local, file-based persistence (no external database)

## Running it locally

```bash
mix deps.get
mix phx.server
```

Then visit `http://localhost:4000/board/anything` — replace `anything` with whatever slug you want.

To also have an interactive console alongside the running server (useful for poking at board state directly):

```bash
iex -S mix phx.server
```

## Project structure (the interesting parts)

```
lib/slug_board/
  application.ex      # Registry + DynamicSupervisor + Presence wiring
  board_server.ex      # The GenServer: one process per board, holds columns & cards

lib/slug_board_web/
  presence.ex           # Phoenix.Presence module
  live/board_live.ex    # The LiveView: mount, events, and rendering
```

## Known trade-offs

- Board data lives on a single node's disk (DETS). This is intentionally simple for a portfolio-scale project — a production system with real durability needs would look at a shared store instead.
- There's no true authentication — anyone with a board's URL can view and edit it. That's the point of the project, not an oversight, but it's worth stating plainly.
- Deployed on a single Fly.io instance with a persistent volume for the DETS file.

## What this project demonstrates

- Modeling application state as supervised OTP processes instead of database rows
- `Registry` + `DynamicSupervisor` for on-demand, keyed process creation
- Real-time UI updates via `Phoenix.PubSub`, without hand-rolled WebSocket logic
- `Phoenix.Presence` for "who's online" tracking with zero manual bookkeeping
- LiveView JS hooks bridging native browser APIs (drag-and-drop) into server-driven state
- Deliberate trade-offs around persistence for a project with no hosting budget
