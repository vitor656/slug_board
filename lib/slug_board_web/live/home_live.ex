defmodule SlugBoardWeb.HomeLive do
  use SlugBoardWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("go_to_board", %{"slug" => raw_slug}, socket) do
    case slugify(raw_slug) do
      "" ->
        {:noreply, put_flash(socket, :error, "Enter a name for your board")}

      slug ->
        {:noreply, push_navigate(socket, to: ~p"/board/#{slug}")}
    end
  end

  defp slugify(raw) do
    raw
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex min-h-screen items-center justify-center bg-paper px-4 font-body text-ink">
      <div class="w-full max-w-lg space-y-8 text-center">
        <div class="space-y-3">
          <h1 class="font-display text-3xl font-semibold sm:text-4xl">SlugBoard</h1>
          
          <p class="text-ink/70">A real-time Kanban board that lives at whatever URL you give it.
            No sign-up — just pick a name and start organizing.</p>
        </div>
        
        <form phx-submit="go_to_board" class="flex flex-col gap-3 sm:flex-row">
          <div class="flex flex-1 items-center rounded-md border border-line bg-card px-3 py-2 text-left">
            <span class="font-mono text-sm text-ink/40">/board/</span>
            <input
              type="text"
              name="slug"
              placeholder="team-standup"
              autofocus
              class="w-full bg-transparent font-mono text-sm focus:outline-none"
            />
          </div>
          
          <button
            type="submit"
            class="shrink-0 rounded-md bg-moss px-5 py-2 font-display font-medium text-white transition hover:bg-moss/90 focus:outline-none focus:ring-2 focus:ring-moss focus:ring-offset-2"
          >
            Create / Join
          </button>
        </form>
        
        <p :if={@flash[:error]} class="text-sm text-red-600">{@flash[:error]}</p>
        
        <p class="text-xs text-ink/50">
          Boards are created the moment you visit their URL — share the link with anyone to collaborate live.
        </p>
      </div>
    </div>
    """
  end
end
