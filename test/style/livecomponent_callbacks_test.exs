# Copyright 2024 Adobe. All rights reserved.
# This file is licensed to you under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License. You may obtain a copy
# of the License at http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software distributed under
# the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
# OF ANY KIND, either express or implied. See the License for the specific language
# governing permissions and limitations under the License.

defmodule Styler.Style.LivecomponentCallbacksTest do
  use Styler.StyleCase, async: true

  test "reorders callbacks in a LiveComponent module" do
    assert_style(
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def mount(socket) do
          {:ok, socket}
        end

        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        def update(assigns, socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
          {:ok, socket}
        end

        def update(assigns, socket) do
          {:ok, socket}
        end

        def handle_event("save", params, socket) do
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
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        @impl true
        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        defp helper_function do
          :ok
        end

        @doc "Renders the component"
        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        def mount(socket) do
          {:ok, socket}
        end

        def update(assigns, socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
          {:ok, socket}
        end

        def update(assigns, socket) do
          {:ok, socket}
        end

        @impl true
        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        @doc "Renders the component"
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

  test "does not affect non-LiveComponent modules" do
    assert_style("""
    defmodule MyAppWeb.MyController do
      @moduledoc false
      use MyAppWeb, :controller

      def handle_event("save", params, socket) do
        {:noreply, socket}
      end

      def mount(socket) do
        {:ok, socket}
      end
    end
    """)
  end

  test "preserves module directive order in LiveComponent modules" do
    assert_style(
      """
      defmodule MyAppWeb.MyComponent do
        require Phoenix.Component
        use MyAppWeb, :live_component
        alias MyApp.Users
        import Phoenix.HTML
        @moduledoc "My Component"

        def mount(socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc "My Component"

        use MyAppWeb, :live_component

        import Phoenix.HTML

        alias MyApp.Users

        require Phoenix.Component

        def mount(socket) do
          {:ok, socket}
        end
      end
      """
    )
  end

  test "preserves original order within callback groups" do
    assert_style(
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def handle_event("cancel", params, socket) do
          {:noreply, socket}
        end

        def handle_async(:task2, {:ok, :ok}, socket) do
          {:noreply, socket}
        end

        def handle_async(:task1, {:ok, :error}, socket) do
          {:noreply, socket}
        end

        def mount(socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
          {:ok, socket}
        end

        def handle_event("save", params, socket) do
          {:noreply, socket}
        end

        def handle_event("cancel", params, socket) do
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
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

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

        def mount(socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
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

  test "places attr and slot macros before render" do
    assert_style(
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        attr(:name, :string, required: true)

        def mount(socket) do
          {:ok, socket}
        end

        slot :inner_block
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
          {:ok, socket}
        end

        attr(:name, :string, required: true)

        slot(:inner_block)

        def render(assigns) do
          ~H"<div>Hello</div>"
        end
      end
      """
    )
  end

  test "preserves original order of attr and slot macros" do
    assert_style(
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def render(assigns) do
          ~H"<div>Hello</div>"
        end

        slot(:header)
        attr(:title, :string, required: true)
        slot(:footer)
        attr(:subtitle, :string, default: nil)
        slot(:inner_block)

        def mount(socket) do
          {:ok, socket}
        end
      end
      """,
      """
      defmodule MyAppWeb.MyComponent do
        @moduledoc false
        use MyAppWeb, :live_component

        def mount(socket) do
          {:ok, socket}
        end

        slot(:header)
        attr(:title, :string, required: true)
        slot(:footer)
        attr(:subtitle, :string, default: nil)
        slot(:inner_block)

        def render(assigns) do
          ~H"<div>Hello</div>"
        end
      end
      """
    )
  end
end
