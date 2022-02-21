defmodule ToeWeb.GameLive.Index do
  use ToeWeb, :live_view

  alias Toe.Games
  alias Toe.Games.Game
  alias Toe.Games.Player

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    if connected?(socket) do
      Games.subscribe(slug)
    end

    players = [%Player{name: "jeff", letter: "X"}, %Player{name: "bob", letter: "O"}]
    game = %Game{players: players, slug: slug}

    {:ok, assign(socket, game: game, bid: 0)}
  end

  @impl true
  def handle_params(%{"current_player" => username}, _url, socket) do
    me = Enum.find(socket.assigns.game.players, fn p -> p.name == username end)
    {:noreply, socket |> assign(me: me, username: username)}
  end

  @impl true
  def handle_event("select", %{"name" => name}, socket) do
    square = Enum.find(socket.assigns.game.board, fn s -> s.name == String.to_atom(name) end)

    cond do
      socket.assigns.game.status == :done ->
        {:noreply, socket |> put_flash(:info, "The game is over!")}

      socket.assigns.game.status != :selecting ->
        {:noreply, socket |> put_flash(:error, "We're in bidding phase, select a square after!")}

      Games.current_player_turn(socket.assigns.game).name != socket.assigns.me.name ->
        {:noreply, socket |> put_flash(:error, "It's not your turn to select!")}

      not Games.can_square_be_selected?(square) ->
        {:noreply, socket |> put_flash(:error, "That square already has been won!")}

      socket.assigns.game.status == :selecting ->
        Games.declare_selected_square(socket.assigns.game, square)
        {:noreply, socket}
    end
  end

  def handle_event("submit-bid", %{"bid" => %{"bid" => bid}}, socket) do
    if Games.has_bid_already?(socket.assigns.game, socket.assigns.me) do
      {:noreply, socket |> put_flash(:error, "You've already bid!")}
    else
      bid = String.to_integer(bid)
      Games.submit_bid(socket.assigns.game, socket.assigns.me, bid)
      {:noreply, socket |> assign(bid: 0)}
    end
  end

  def handle_event("validate", %{"bid" => %{"bid" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"bid" => %{"bid" => bid}}, socket) when bid != "" do
    if String.to_integer(bid) > socket.assigns.me.points do
      {:noreply, socket |> put_flash(:error, "You don't have enough points!")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:game_updated, game}, socket) do
    me = Enum.find(game.players, fn p -> p.name == socket.assigns.username end)
    {:noreply, assign(socket, game: game, me: me) |> clear_flash()}
  end
end
