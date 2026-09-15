defmodule SlugBoard.BoardServer do
  use GenServer

  def start_link(slug) do
    GenServer.start_link(__MODULE__, slug, name: via_tuple(slug))
  end

  def get_state(slug) do
    GenServer.call(via_tuple(slug), :get_state)
  end

  def add_column(slug, title) do
    GenServer.call(via_tuple(slug), {:add_column, title})
  end

  def add_card(slug, column_id, text) do
    GenServer.call(via_tuple(slug), {:add_card, column_id, text})
  end

  def move_card(slug, card_id, target_column_id) do
    GenServer.call(via_tuple(slug), {:move_card, card_id, target_column_id})
  end

  def update_card(slug, card_id, text) do
    GenServer.call(via_tuple(slug), {:update_card, card_id, text})
  end

  def delete_card(slug, card_id) do
    GenServer.call(via_tuple(slug), {:delete_card, card_id})
  end

  def update_column(slug, column_id, title) do
    GenServer.call(via_tuple(slug), {:update_column, column_id, title})
  end

  def delete_column(slug, column_id) do
    GenServer.call(via_tuple(slug), {:delete_column, column_id})
  end

  defp via_tuple(slug) do
    {:via, Registry, {SlugBoard.BoardRegistry, slug}}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8)
    |> Base.encode16(case: :lower)
  end

  @impl true
  def init(slug) do
    state =
      case :dets.lookup(:boards_dets, slug) do
        [{^slug, saved_state}] ->
          saved_state

        [] ->
          %{
            slug: slug,
            columns: [
              %{id: "todo", title: "To Do"},
              %{id: "doing", title: "In Progress"},
              %{id: "done", title: "Done"}
            ],
            cards: []
          }
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_column, title}, _from, state) do
    column = %{id: generate_id(), title: title}
    new_state = %{state | columns: state.columns ++ [column]}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:add_card, column_id, text}, _from, state) do
    card = %{id: generate_id(), column_id: column_id, text: text}
    new_state = %{state | cards: state.cards ++ [card]}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:move_card, card_id, target_column_id}, _from, state) do
    new_cards =
      Enum.map(state.cards, fn card ->
        if card.id == card_id, do: %{card | column_id: target_column_id}, else: card
      end)

    new_state = %{state | cards: new_cards}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:delete_card, card_id}, _from, state) do
    new_cards = Enum.reject(state.cards, &(&1.id == card_id))
    new_state = %{state | cards: new_cards}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:update_card, card_id, text}, _from, state) do
    new_cards =
      Enum.map(state.cards, fn card ->
        if card.id == card_id, do: %{card | text: text}, else: card
      end)

    new_state = %{state | cards: new_cards}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:update_column, column_id, title}, _from, state) do
    new_columns =
      Enum.map(state.columns, fn column ->
        if column.id == column_id, do: %{column | title: title}, else: column
      end)

    new_state = %{state | columns: new_columns}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:delete_column, column_id}, _from, state) do
    new_columns = Enum.reject(state.columns, &(&1.id == column_id))
    new_cards = Enum.reject(state.cards, &(&1.column_id == column_id))

    new_state = %{state | columns: new_columns, cards: new_cards}
    broadcast_update(state.slug, new_state)
    {:reply, new_state, new_state}
  end

  def ensure_started(slug) do
    case DynamicSupervisor.start_child(SlugBoard.BoardSupervisor, {__MODULE__, slug}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
    end
  end

  defp broadcast_update(slug, new_state) do
    :dets.insert(:boards_dets, {slug, new_state})
    Phoenix.PubSub.broadcast(SlugBoard.PubSub, "board:#{slug}", {:board_updated, new_state})
  end
end
