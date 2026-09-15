defmodule SlugBoardWeb.PageController do
  use SlugBoardWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
