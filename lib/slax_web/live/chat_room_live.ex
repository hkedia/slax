defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Chat
  alias Slax.Chat.{Room, Message}

  attr :active, :boolean, required: true
  attr :room, Room, required: true

  defp room_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center h-8 text-sm pl-8 pr-3",
        (@active && "bg-slate-300") || "hover:bg-slate-300"
      ]}
      id={@dom_id}
      patch={~p"/rooms/#{@room}"}
    >
      <.icon name="hero-hashtag" class="h-4 w-4" />
      <span class={["ml-2 leading-none", @active && "font-bold"]}>
        <%= @room.name %>
      </span>
    </.link>
    """
  end

  attr :message, Message, required: true
  attr :dom_id, :string, required: true

  defp message(assigns) do
    ~H"""
    <div id={@dom_id} class="relative flex px-4 py-3">
      <div class="h-10 w-10 rounded flex-shrink-0 bg-slate-300"></div>
      <div class="ml-2">
        <div class="-mt-1">
          <.link class="text-sm font-semibold hover:underline">
            <span>
              <%= username(@message.user) %>
            </span>
          </.link>
          <p class="text-sm"><%= @message.body %></p>
        </div>
      </div>
    </div>
    """
  end

  defp username(user) do
    user.email
    |> String.split("@")
    |> List.first()
    |> String.capitalize()
  end

  def mount(_params, _session, socket) do
    rooms = Chat.list_rooms()

    socket =
      socket
      |> stream(:rooms, rooms)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Chat.get_room!(id)

        :error ->
          Chat.get_first_room!()
      end

    messages = Chat.list_messages_in_room(room)

    socket =
      socket
      |> assign(hide_topic?: false)
      |> assign(room: room)
      |> stream(:messages, messages, reset: true)
      |> assign(page_title: "#" <> room.name)
      |> assign_message_form(Chat.change_message(%Message{}))

    {:noreply, socket}
  end

  def handle_event("submit-message", %{"message" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    socket =
      case Chat.create_message(room, message_params, current_user) do
        {:ok, message} ->
          socket
          |> stream_insert(:messages, message)
          |> assign_message_form(Chat.change_message(%Message{}))

        {:error, changeset} ->
          assign_message_form(socket, changeset)
      end

    {:noreply, socket}
  end

  def handle_event("toggle-topic", _, socket) do
    socket =
      socket
      |> update(:hide_topic?, &(!&1))

    {:noreply, socket}
  end

  def handle_event("validate-message", %{"message" => message_params}, socket) do
    changeset = Chat.change_message(%Message{}, message_params)

    {:noreply, assign_message_form(socket, changeset)}
  end

  defp assign_message_form(socket, changeset) do
    assign(socket, :new_message_form, to_form(changeset))
  end
end
