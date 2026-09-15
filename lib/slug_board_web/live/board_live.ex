defmodule SlugBoardWeb.BoardLive do
  use SlugBoardWeb, :live_view

  alias SlugBoardWeb.Presence
  alias SlugBoard.BoardServer

  @avatar_colors ["#5E7A52", "#B98A2E", "#6B8CAE", "#B25D5D", "#8A6BAE"]

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    {:ok, _pid} = BoardServer.ensure_started(slug)
    board = BoardServer.get_state(slug)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(SlugBoard.PubSub, "board:#{slug}")
    end

    socket =
      socket
      |> assign(:slug, slug)
      |> assign(:board, board)
      |> assign(:username, nil)
      |> assign(:viewers, [])
      |> assign(:modal, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("move_card", %{"card_id" => card_id, "column_id" => column_id}, socket) do
    BoardServer.move_card(socket.assigns.slug, card_id, column_id)
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_column", %{"title" => title}, socket) do
    BoardServer.add_column(socket.assigns.slug, title)
    {:noreply, socket}
  end

  @impl true
  def handle_event("open_add_card", %{"column-id" => column_id}, socket) do
    {:noreply, assign(socket, :modal, {:new_card, column_id})}
  end

  @impl true
  def handle_event("open_view_card", %{"card-id" => card_id}, socket) do
    card = Enum.find(socket.assigns.board.cards, &(&1.id == card_id))
    {:noreply, assign(socket, :modal, {:view_card, card})}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("add_card", %{"column_id" => column_id, "text" => text}, socket) do
    if String.trim(text) != "" do
      BoardServer.add_card(socket.assigns.slug, column_id, text)
    end

    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("delete_card", %{"card-id" => card_id}, socket) do
    BoardServer.delete_card(socket.assigns.slug, card_id)
    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("update_card", %{"card_id" => card_id, "text" => text}, socket) do
    if String.trim(text) != "" do
      BoardServer.update_card(socket.assigns.slug, card_id, text)
    end

    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("set_username", %{"username" => username}, socket) when username != "" do
    slug = socket.assigns.slug

    Phoenix.PubSub.subscribe(SlugBoard.PubSub, "board:#{slug}")

    {:ok, _} =
      Presence.track(self(), "presence:board:#{slug}", socket.id, %{
        username: username
      })

    viewers = list_viewers(slug)

    {:noreply,
     socket
     |> assign(:username, username)
     |> assign(:viewers, viewers)}
  end

  @impl true
  def handle_event("open_edit_column", %{"column-id" => column_id}, socket) do
    column = Enum.find(socket.assigns.board.columns, &(&1.id == column_id))
    {:noreply, assign(socket, :modal, {:edit_column, column})}
  end

  @impl true
  def handle_event("update_column", %{"column_id" => column_id, "title" => title}, socket) do
    if String.trim(title) != "" do
      BoardServer.update_column(socket.assigns.slug, column_id, title)
    end

    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_event("delete_column", %{"column-id" => column_id}, socket) do
    BoardServer.delete_column(socket.assigns.slug, column_id)
    {:noreply, assign(socket, :modal, nil)}
  end

  @impl true
  def handle_info({:board_updated, new_board}, socket) do
    {:noreply, assign(socket, :board, new_board)}
  end

  @impl true
  def handle_info(%{event: "presence_diff"}, socket) do
    viewers = list_viewers(socket.assigns.slug)
    {:noreply, assign(socket, :viewers, viewers)}
  end

  defp list_viewers(slug) do
    Presence.list("presence:board:#{slug}")
    |> Enum.map(fn {_key, %{metas: [meta | _]}} -> meta.username end)
  end

  defp avatar_color(value) do
    index = :erlang.phash2(value, length(@avatar_colors))
    Enum.at(@avatar_colors, index)
  end

  defp initials(name) do
    name
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
    |> String.upcase()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-paper font-body text-ink">
      <div :if={@username == nil} class="flex min-h-screen items-center justify-center px-4">
        <form phx-submit="set_username" class="w-full max-w-sm space-y-4">
          <h1 class="font-display text-2xl font-semibold">Join this board</h1>
          
          <p class="text-sm text-ink/70">Anyone with this link can see and edit it.</p>
          
          <input
            type="text"
            name="username"
            placeholder="Your name"
            autofocus
            class="w-full rounded-md border border-line bg-card px-3 py-2 focus:outline-none focus:ring-2 focus:ring-moss"
          />
          <button
            type="submit"
            class="w-full rounded-md bg-moss px-4 py-2 font-display font-medium text-white transition hover:bg-moss/90 focus:outline-none focus:ring-2 focus:ring-moss focus:ring-offset-2"
          >
            Join board
          </button>
        </form>
      </div>
      
      <div :if={@username != nil}>
        <header class="flex items-center justify-between border-b border-line bg-card px-4 py-3 sm:px-6">
          <div class="flex items-center gap-1 rounded-md border border-line bg-paper px-3 py-1.5">
            <span class="font-mono text-sm text-ink/40">/board/</span>
            <span class="font-mono text-sm font-medium">{@slug}</span>
          </div>
          
          <div class="flex items-center -space-x-2">
            <div
              :for={viewer <- @viewers}
              class="flex h-8 w-8 items-center justify-center rounded-full border-2 border-card font-display text-xs font-semibold text-white"
              style={"background-color: #{avatar_color(viewer)}"}
              title={viewer}
            >
              {initials(viewer)}
            </div>
          </div>
        </header>
        
        <main class="flex snap-x snap-mandatory gap-4 overflow-x-auto p-4 sm:snap-none sm:p-6">
          <div
            :for={column <- @board.columns}
            class="flex w-[85vw] max-w-xs shrink-0 snap-start flex-col gap-3 sm:w-72"
          >
            <button
              type="button"
              phx-click="open_edit_column"
              phx-value-column-id={column.id}
              class="text-left font-display font-semibold text-ink hover:text-moss"
            >
              {column.title}
            </button>
            <div
              id={"column-#{column.id}"}
              phx-hook="DropZone"
              data-column-id={column.id}
              class="flex min-h-[80px] flex-col gap-2 rounded-md transition-all duration-150"
            >
              <div
                :for={card <- Enum.filter(@board.cards, &(&1.column_id == column.id))}
                id={"card-#{card.id}"}
                phx-hook="Draggable"
                draggable="true"
                data-card-id={card.id}
                phx-click="open_view_card"
                phx-value-card-id={card.id}
                class="cursor-grab rounded-md border-l-4 bg-card px-3 py-2 shadow-sm active:cursor-grabbing"
                style={"border-left-color: #{avatar_color(column.id)}"}
              >
                <p class="line-clamp-3 break-words text-sm">{card.text}</p>
              </div>
            </div>
            
            <button
              type="button"
              phx-click="open_add_card"
              phx-value-column-id={column.id}
              class="rounded-md border border-dashed border-line px-3 py-2 text-left text-sm text-ink/60 hover:border-moss hover:text-ink"
            >
              + Add a card
            </button>
          </div>
          
          <form
            phx-submit="add_column"
            class="flex w-[85vw] max-w-xs shrink-0 snap-start flex-col gap-2 sm:w-72"
          >
            <input
              type="text"
              name="title"
              placeholder="+ Add column"
              class="w-full rounded-md border border-dashed border-line bg-transparent px-3 py-2 text-sm text-ink/60 focus:outline-none focus:ring-2 focus:ring-moss"
            />
          </form>
        </main>
      </div>
      
      <div :if={@modal} class="fixed inset-0 z-50 flex items-center justify-center bg-ink/40 px-4">
        <div class="w-full max-w-md rounded-lg bg-card p-5 shadow-lg" phx-click-away="close_modal">
          <%= case @modal do %>
            <% {:new_card, column_id} -> %>
              <h3 class="mb-3 font-display font-semibold">New card</h3>
              
              <form phx-submit="add_card">
                <input type="hidden" name="column_id" value={column_id} /> <textarea
                  name="text"
                  rows="4"
                  autofocus
                  placeholder="Describe the task..."
                  class="w-full rounded-md border border-line bg-paper px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-moss"
                ></textarea>
                <div class="mt-3 flex justify-end gap-2">
                  <button
                    type="button"
                    phx-click="close_modal"
                    class="rounded-md px-3 py-1.5 text-sm text-ink/60 hover:text-ink"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    class="rounded-md bg-moss px-3 py-1.5 font-display text-sm font-medium text-white hover:bg-moss/90"
                  >
                    Add card
                  </button>
                </div>
              </form>
            <% {:view_card, card} -> %>
              <h3 class="mb-3 font-display font-semibold">Edit card</h3>
              
              <form phx-submit="update_card">
                <input type="hidden" name="card_id" value={card.id} /> <textarea
                  name="text"
                  rows="4"
                  autofocus
                  class="w-full rounded-md border border-line bg-paper px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-moss"
                >{card.text}</textarea>
                <div class="mt-3 flex items-center justify-between">
                  <button
                    type="button"
                    phx-click="delete_card"
                    phx-value-card-id={card.id}
                    data-confirm="Delete this card?"
                    class="text-sm text-red-600 hover:text-red-700"
                  >
                    Delete
                  </button>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="close_modal"
                      class="rounded-md px-3 py-1.5 text-sm text-ink/60 hover:text-ink"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="rounded-md bg-moss px-3 py-1.5 font-display text-sm font-medium text-white hover:bg-moss/90"
                    >
                      Save
                    </button>
                  </div>
                </div>
              </form>
            <% {:edit_column, column} -> %>
              <h3 class="mb-3 font-display font-semibold">Edit column</h3>
              
              <form phx-submit="update_column">
                <input type="hidden" name="column_id" value={column.id} />
                <input
                  type="text"
                  name="title"
                  value={column.title}
                  autofocus
                  class="w-full rounded-md border border-line bg-paper px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-moss"
                />
                <div class="mt-3 flex items-center justify-between">
                  <button
                    type="button"
                    phx-click="delete_column"
                    phx-value-column-id={column.id}
                    data-confirm="Delete this column and all its cards? This can't be undone."
                    class="text-sm text-red-600 hover:text-red-700"
                  >
                    Delete column
                  </button>
                  <div class="flex gap-2">
                    <button
                      type="button"
                      phx-click="close_modal"
                      class="rounded-md px-3 py-1.5 text-sm text-ink/60 hover:text-ink"
                    >
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="rounded-md bg-moss px-3 py-1.5 font-display text-sm font-medium text-white hover:bg-moss/90"
                    >
                      Save
                    </button>
                  </div>
                </div>
              </form>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
