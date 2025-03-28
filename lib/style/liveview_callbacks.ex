defmodule Styler.Style.LiveviewCallbacks do
  @moduledoc """
  Orders LiveView callbacks in an idiomatic order.

  The order is:
  1. mount/3
  2. handle_params/3
  3. handle_event/3
  4. handle_info/2
  5. handle_async/2
  6. handle_call/3
  7. handle_cast/2
  8. update/2
  9. terminate/2
  10. render/1

  This style only applies to modules that use `use YourAppWeb, :live_view`.
  """

  @behaviour Styler.Style

  alias Styler.Zipper

  @callback_order %{
    "mount" => 1,
    "handle_params" => 2,
    "handle_event" => 3,
    "handle_info" => 4,
    "handle_async" => 5,
    "handle_call" => 6,
    "handle_cast" => 7,
    "update" => 8,
    "terminate" => 9,
    "render" => 10
  }

  def run({{:defmodule, _meta, [_name, [{{:__block__, _, [:do]}, {:__block__, _, body_statements}}]]}, _} = zipper, ctx) do
    if is_liveview_module_body?(body_statements) do
      case reorder_callbacks(zipper, ctx) do
        {:replace, new_node, _meta} -> {:skip, Zipper.replace(zipper, new_node), ctx}
        {:skip, zipper, ctx} -> {:skip, zipper, ctx}
      end
    else
      {:skip, zipper, ctx}
    end
  end

  def run(zipper, ctx), do: {:cont, zipper, ctx}

  defp is_liveview_module_body?(statements) when is_list(statements) do
    result =
      Enum.any?(statements, fn
        {:use, _, [{:__aliases__, _, _module}, {:__block__, _, [:live_view]}]} ->
          true

        {:use, _, [{:__aliases__, _, _module}, [do: :live_view]]} ->
          true

        {:use, _, [{:__aliases__, _, _module}, keyword_list]} when is_list(keyword_list) ->
          Keyword.get(keyword_list, :do) == :live_view

        _ ->
          false
      end)

    result
  end

  defp is_liveview_module_body?(_), do: false

  defp reorder_callbacks(zipper, ctx) do
    case Zipper.node(zipper) do
      {:defmodule, meta, [name, [{{:__block__, do_meta, [:do]}, {:__block__, block_meta, statements}}]]} ->
        case extract_use_statement(statements) do
          {nil, _} ->
            {:skip, zipper, ctx}

          {use_stmt, rest_statements} ->
            # Split statements into different types
            {moduledoc, other_statements} = split_moduledoc(rest_statements)
            {directives, other_statements} = split_module_directives(other_statements)

            # Group statements by type and attach attributes to callbacks
            {on_mount_hooks, callbacks, other_statements} = extract_callbacks(other_statements)

            # Sort module directives by type
            sorted_directives = sort_module_directives(directives)

            # Sort callbacks while preserving their attributes
            sorted_callbacks = sort_callbacks(callbacks)

            # Combine everything back in the correct order:
            # 1. moduledoc
            # 2. use statement
            # 3. module directives (import, alias, require, etc.)
            # 4. on_mount hooks
            # 5. callbacks
            # 6. other statements
            new_statements =
              moduledoc ++
                [use_stmt] ++
                sorted_directives ++
                on_mount_hooks ++
                sorted_callbacks ++
                other_statements

            new_body_block = {:__block__, block_meta, new_statements}
            new_do_structure = [{{:__block__, do_meta, [:do]}, new_body_block}]
            new_node = {:defmodule, meta, [name, new_do_structure]}
            {:replace, new_node, meta}
        end

      _ ->
        {:skip, zipper, ctx}
    end
  end

  # Split moduledoc from other statements
  defp split_moduledoc(statements) do
    Enum.split_with(statements, fn
      {:@, _, [{:moduledoc, _, _}]} -> true
      _ -> false
    end)
  end

  # Split module directives from other statements
  defp split_module_directives(statements) do
    Enum.split_with(statements, fn
      {:import, _, _} -> true
      {:alias, _, _} -> true
      {:require, _, _} -> true
      _ -> false
    end)
  end

  # Sort module directives by type
  defp sort_module_directives(directives) do
    Enum.sort_by(directives, fn
      {:import, _, _} -> 1
      {:alias, _, _} -> 2
      {:require, _, _} -> 3
      _ -> 999
    end)
  end

  # Extract callbacks, on_mount hooks, and group attributes with their callbacks
  defp extract_callbacks(statements) do
    {callbacks_with_attrs, remaining} = extract_callbacks_with_attrs(statements)
    {on_mount_hooks, other_statements} = extract_on_mount_hooks(remaining)
    {on_mount_hooks, callbacks_with_attrs, other_statements}
  end

  # Extract on_mount hooks from statements
  defp extract_on_mount_hooks(statements) do
    Enum.split_with(statements, fn
      {:on_mount, _, _} -> true
      _ -> false
    end)
  end

  # Extract callbacks with their attributes
  defp extract_callbacks_with_attrs(statements) do
    # First pass: Identify callbacks and collect attributes that come before them
    {callbacks_data, other_statements, _current_attrs} =
      Enum.reduce(statements, {[], [], []}, fn
        # Process attributes
        {:@, _, _} = attr, {callbacks, others, attrs} ->
          {callbacks, others, [attr | attrs]}

        # Process callbacks with their attributes
        {:def, _, [{:when, _, [{name, _, _} | _]} | _]} = callback, {callbacks, others, attrs} ->
          if Map.has_key?(@callback_order, Atom.to_string(name)) do
            {[{callback, Enum.reverse(attrs)} | callbacks], others, []}
          else
            # Not a LiveView callback
            {callbacks, others ++ Enum.reverse(attrs, [callback]), []}
          end

        {:def, _, [{name, _, _} | _]} = callback, {callbacks, others, attrs} ->
          if Map.has_key?(@callback_order, Atom.to_string(name)) do
            {[{callback, Enum.reverse(attrs)} | callbacks], others, []}
          else
            # Not a LiveView callback
            {callbacks, others ++ Enum.reverse(attrs, [callback]), []}
          end

        # Process other statements
        other, {callbacks, others, attrs} ->
          {callbacks, others ++ Enum.reverse(attrs, [other]), []}
      end)

    # Group callbacks by their name (ignoring guards)
    grouped_callbacks =
      Enum.group_by(callbacks_data, fn {callback, _attrs} ->
        case callback do
          {:def, _, [{:when, _, [{name, _, _} | _]} | _]} -> name
          {:def, _, [{name, _, _} | _]} -> name
        end
      end)

    # Keep callbacks in their original order within each group
    sorted_callbacks =
      grouped_callbacks
      |> Enum.sort_by(fn {name, _callbacks} ->
        @callback_order[Atom.to_string(name)] || 999_999
      end)
      |> Enum.flat_map(fn {_name, callbacks} ->
        # Reverse the callbacks to maintain original order since we collected them in reverse
        Enum.reverse(callbacks)
      end)

    # Return callbacks with their attributes and other statements
    {sorted_callbacks, other_statements}
  end

  # Sort callbacks while keeping attributes with their callbacks
  defp sort_callbacks(callbacks_data) do
    # Group callbacks by their base name (ignoring guards)
    grouped_callbacks =
      Enum.group_by(callbacks_data, fn {callback, _attrs} ->
        case callback do
          {:def, _, [{:when, _, [{name, _, _} | _]} | _]} -> name
          {:def, _, [{name, _, _} | _]} -> name
        end
      end)

    # Sort the groups by callback order
    sorted_groups =
      Enum.sort_by(grouped_callbacks, fn {name, _callbacks} ->
        @callback_order[Atom.to_string(name)] || 999_999
      end)

    # Flatten the groups back into a list, preserving original order within groups
    sorted_groups
    |> Enum.flat_map(fn {_name, callbacks} -> callbacks end)
    |> Enum.flat_map(fn {callback, attrs} -> attrs ++ [callback] end)
  end

  defp extract_use_statement(statements) do
    case Enum.find(statements, fn
           {:use, _, _} -> true
           _ -> false
         end) do
      nil ->
        {nil, statements}

      use_stmt ->
        rest = Enum.reject(statements, &(&1 == use_stmt))
        {use_stmt, rest}
    end
  end
end
