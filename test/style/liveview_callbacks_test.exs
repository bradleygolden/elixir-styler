# Copyright 2024 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

defmodule Styler.Style.LiveviewCallbacksTest do
  use Styler.StyleCase, async: true

  test "reorders callbacks in a LiveView module" do
    assert_style(
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        def handle_info(:tick, socket) do
          {:noreply, socket}
        end

        def handle_params(params, _url, socket) do
          {:noreply, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_params(params, _url, socket) do
          {:noreply, socket}
        end

        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def handle_info(:tick, socket) do
          {:noreply, socket}
        end

        def render(assigns) do
          ~H"<div>Hello</div>"
        end
      end
      """
    )
  end

  test "preserves non-callback functions and module attributes" do
    assert_style(
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        @impl true
        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        defp helper_function do
          :ok
        end

        @doc "Renders the view"
        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_info(:tick, socket) do
          {:noreply, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        @impl true
        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def handle_info(:tick, socket) do
          {:noreply, socket}
        end

        @doc "Renders the view"
        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        defp helper_function do
          :ok
        end
      end
      """
    )
  end

  test "does not affect non-LiveView modules" do
    assert_style("""
    defmodule MyAppWeb.MyController do
      use MyAppWeb, :controller

      def handle_event("save", params, socket) do
        {:noreply, socket}
      end

      def mount(_params, _session, socket) do
        {:ok, socket}
      end
    end
    """)
  end

  test "preserves module directive order in LiveView modules" do
    assert_style(
      """
      defmodule MyAppWeb.MyLiveView do
        require Phoenix.Component
        use MyAppWeb, :live_view
        alias MyApp.Users
        import Phoenix.HTML
        @moduledoc "My LiveView"

        def mount(_params, _session, socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyLiveView do
        @moduledoc "My LiveView"

        use MyAppWeb, :live_view

        import Phoenix.HTML

        alias MyApp.Users

        require Phoenix.Component

        def mount(_params, _session, socket) do
          {:ok, socket}
        end
      end
      """
    )
  end

  test "preserves original order within callback groups" do
    assert_style(
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def handle_info({:message_sent, messages}, socket) do
          {:noreply, socket}
        end

        def handle_info({:message_response, data}, socket) do
          {:noreply, socket}
        end

        def handle_async(:task2, {:ok, :ok}, socket) do
          {:noreply, socket}
        end

        def handle_async(:task1, {:ok, :error}, socket) do
          {:noreply, socket}
        end

        def mount(_params, _session, socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_info({:message_sent, messages}, socket) do
          {:noreply, socket}
        end

        def handle_info({:message_response, data}, socket) do
          {:noreply, socket}
        end

        def handle_async(:task2, {:ok, :ok}, socket) do
          {:noreply, socket}
        end

        def handle_async(:task1, {:ok, :error}, socket) do
          {:noreply, socket}
        end
      end
      """
    )
  end

  test "preserves original order in complex callback groups" do
    assert_style(
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def handle_event("confirm_skip", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("cancel_skip", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("show_skip_confirmation", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("continue_to_dashboard", _params, socket) do
          {:noreply, socket}
        end

        def mount(_params, _session, socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyLiveView do
        use MyAppWeb, :live_view

        def mount(_params, _session, socket) do
          {:ok, socket}
        end

        def handle_event("confirm_skip", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("cancel_skip", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("show_skip_confirmation", _params, socket) do
          {:noreply, socket}
        end

        def handle_event("continue_to_dashboard", _params, socket) do
          {:noreply, socket}
        end
      end
      """
    )
  end
end
