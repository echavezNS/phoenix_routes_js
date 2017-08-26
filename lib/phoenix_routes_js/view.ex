defmodule PhoenixRoutesJs.View do
  import Phoenix.HTML
  import Phoenix.HTML.Tag

  def render_routes_script(conn) do
    routes = Map.to_list(PhoenixRoutesJs.Routes.fetch(conn.private[:phoenix_router]))

    content_tag(:script, [type: "text/javascript"]) do
      raw(script(routes))
    end
  end


  defp script(routes) do
    """

    var Routes = (function(window) {
      function RoutesError(name, action, args) {
        this.message = "route " + name + "(" + action + ", " + args.join(", ") + ") doesn't exists!";
      };

      function render_options(options = {}) {
        if (Object.keys(options).length === 0) return "";

        var format = options['format'] && (options['format'].length !== 0) ? '.' + options['format'] : "";
        var params = options['params'] || {};
        var options_string = '';

        if (format.length > 1) { options_string = options_string + format; }

        if (Object.keys(params).length > 0) {
          queries = [];

          for (param in params) {
            queries.push(param + '=' + params[param]);
          };

          options_string = options_string + '?' + queries.join('&');
        }

        return options_string;
      };

      return {
        #{Enum.join(render_routes_functions(routes))}
      };
    })(window);
    """
  end


  defp render_routes_functions(routes) do
    render_routes_functions(routes, [])
  end

  defp render_routes_functions([route | routes], functions) do
    render_routes_functions(routes, functions ++ [render_route(route)])
  end

  defp render_routes_functions([], functions), do: functions


  defp render_route({function_name, actions}) do
    function = function_name <> "_path"
    actions_list = Map.keys(actions) |> Enum.map(fn(key) -> '"#{key}"' end) |> Enum.join(", ")
    actions = Map.to_list(actions)
    """

        #{function}: function(action = 'index', ...rest) {
          var notFoundIndex = -1;
          var actions = [#{actions_list}];
          var function_name = '#{function}';
          var args = Array.from(rest);
          var options = typeof(args[args.length - 1]) === 'object' ? args.pop() : {};
          var self = {};

          #{Enum.join(render_actions_functions(actions))}

          if (actions.indexOf(action) !== notFoundIndex) {
            return self[action](args, options);
          } else { throw new RoutesError('#{function}', action, args); }
        },
    """
  end


  defp render_actions_functions(actions) do
    render_actions_functions(actions, [])
  end

  defp render_actions_functions([action | actions], functions) do
    render_actions_functions(actions, functions ++ [render_action(action)])
  end

  defp render_actions_functions([], functions), do: functions


  defp render_action({action, pattern}) do
    [args, path, length] = arguments(pattern)
    """

          self['#{action}'] = function(args, options) {
            var length = #{length};
            var vars = '#{args}'.split(', ').filter(Boolean);
            #{render_variables(args)}

            if (vars.length != args.length) { throw new RoutesError(function_name, '#{action}', args) }

            return '#{path}' + render_options(options);
          };
    """
  end

  defp arguments(pattern) do
    paths = String.split(pattern, "/")

    args = paths
      |> Enum.filter(&argument_filter/1)
      |> Enum.map(&argument_normalizer/1)

    args_string = args
      |> render_arguments_string

    path_string = paths
      |> Enum.map(&path_normalizer/1)
      |> render_path_string

    [args_string, path_string, length(args)]
  end

  defp argument_filter(path), do: String.starts_with?(path, ":")

  defp argument_normalizer(path), do: String.replace_prefix(path, ":", "")

  defp render_arguments_string(args), do: Enum.join(args, ", ")

  defp path_normalizer(path) do
    case String.starts_with?(path, ":") do
      true ->
        "' + #{String.replace_prefix(path, ":", "")} + '"
      false ->
        path
    end
  end

  defp render_path_string(paths), do: Enum.join(paths, "/")

  defp render_variables(args) do
    cond do
      String.contains?(args, ",") ->
        args
          |> String.split(",")
          |> Enum.with_index
          |> Enum.map(&vars_normalizer/1)
          |> render_vars_string
      args != "" ->
        "var #{args} = args[0];"
      args == "" ->
        nil
    end
  end

  defp vars_normalizer({key, index}), do: "var #{key} = args[#{index}];\n"

  defp render_vars_string(vars), do: Enum.join(vars, "")
end

