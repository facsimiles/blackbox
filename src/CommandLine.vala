/* CommandLine.vala
 *
 * Copyright 2022 Paulo Queiroz <pvaqueiroz@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public struct Terminal.CommandLineOptions {
  string? command;
  string? current_working_dir;
  bool    version;
  bool    help;
}

//  Usage:
//    blackbox [OPTION…] [-- COMMAND ...]
//
//  Options:
//    -v, --version               Show app version
//    -w, --working-directory     Set current working directory
//    -c, --command               Execute command in a terminal
//    -h, --help                  Show help

public class Terminal.CommandLine {
  public static bool parse_command_line (GLib.ApplicationCommandLine cmd,
                                         out CommandLineOptions options)
  {
    options = {};

    OptionEntry[] option_entries = {
      OptionEntry () {
        long_name       = "version",
        short_name      = 'v',
        description     = _("Show app version"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.NONE,
        arg_data        = &options.version,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "working-directory",
        short_name      = 'w',
        description     = _("Set current working directory"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.FILENAME,
        arg_data        = &options.current_working_dir,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "command",
        short_name      = 'c',
        description     = _("Execute command in a terminal"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.STRING,
        arg_data        = &options.command,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "help",
        short_name      = 'h',
        description     = _("Show help"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.NONE,
        arg_data        = &options.help,
        arg_description = null,
      },
    };

    var ctx = new OptionContext ("[-- COMMAND ...]");
    // If this is set to true and the user launches blackbox with --help, the
    // entire GTK application will close (with exit(0)), even if there are other
    // windows open
    ctx.set_help_enabled (false);
    ctx.add_main_entries (option_entries, null);

    // We have to make an extra copy of the array, since .parse assumes
    // that it can remove strings from the array without freeing them.
    string[] args = cmd.get_arguments ();

    try {
      ctx.parse_strv (ref args);

      // The docs for `parse` say that it updates args.length and `parse_strv` says that it is like `parse`. However it doesn't appear to actually update length, so let's do that for it.
      while (args.length > 0 && args[args.length - 1] == null) {
        args.length -= 1;
      }

      if (options.help) {
        cmd.print_literal (ctx.get_help (true, null));
      } else if (args.length > 1) {
        if (options.command != null) {
          cmd.printerr (_("-c and positional arguments are mutally exclusive\n"));
          cmd.printerr (_("Note that -c takes a single quoted command. Use `%s -- vi file.txt` rather than `%s -c vi file.txt`"), args[0], args[0]);
          return false;
        }

        int start_arg = args[1] == "--" ? 2 : 1;
        for (int i = start_arg; i < args.length; i++) {
          args[i] = GLib.Shell.quote (args[i]);
        }
        options.command = string.joinv (" ", args[start_arg:]);
      }
    }
    catch (Error e) {
      cmd.printerr ("%s\n", e.message);
      cmd.printerr (_("Run %s --help to get help\n"), args[0]);
      return false;
    }

    return true;
  }
}
