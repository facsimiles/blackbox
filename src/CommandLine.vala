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
  string[]? command;
  string[]? current_working_dir;
  int       command_cnt;
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
  public static OptionEntry[] option_entries() {
    return {
      OptionEntry () {
        long_name       = "version",
        short_name      = 'v',
        description     = _("Show app version"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.NONE,
        arg_data        = null,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "working-directory",
        short_name      = 'w',
        description     = _("Set current working directory"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.STRING_ARRAY,
        arg_data        = null,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = "command",
        short_name      = 'c',
        description     = _("Execute command in a terminal"),
        flags           = OptionFlags.NONE,
        arg             = OptionArg.STRING_ARRAY,
        arg_data        = null,
        arg_description = null,
      },
      OptionEntry () {
        long_name       = GLib.OPTION_REMAINING,
        short_name      = 0,
        description     = null,
        flags           = OptionFlags.NONE,
        arg             = OptionArg.FILENAME_ARRAY,
        arg_data        = null,
        arg_description = "[-- COMMAND ...]",
      },
    };
  }

  // ------------------------------------ Command line handler in local instance

  private static bool dash_dash_opt = false;

  public static void check_dash_dash_opt (string[] arguments) {
    CommandLine.dash_dash_opt = false;
    for (int i = 1; i < arguments.length; i++) {
      if (arguments[i] == "--") {
        CommandLine.dash_dash_opt = true;
        break;
      }
    }
  }

  public static int? handle_local_options (GLib.VariantDict options) {
    int? exit_status = null;

    // Parse remaining arguments only if `--` option exists
    if (!CommandLine.dash_dash_opt) {
      options.remove (GLib.OPTION_REMAINING);
    }

    bool version = false;
    if (options.lookup ("version", "b", out version)) {
      if (version) {
        print (
          "%s version %s%s\n",
          APP_NAME,
          VERSION,
#if BLACKBOX_IS_FLATPAK
          " (flatpak)"
#else
          ""
#endif
        );
      }
      exit_status = Posix.EXIT_SUCCESS;
    }

    return exit_status;
  }

  // ---------------------------------- Command line handler in primary instance

  public static void parse_command_line (GLib.ApplicationCommandLine cmd,
                                         out CommandLineOptions options)
  {
    options = {};
    GLib.VariantDict dict = cmd.get_options_dict ();

    options.command             = dict.lookup_value ("command", VariantType.STRING_ARRAY)?.dup_strv ();
    options.current_working_dir = dict.lookup_value ("working-directory", VariantType.STRING_ARRAY)?.dup_strv ();
    string[]? argv_after_dd     = dict.lookup_value (GLib.OPTION_REMAINING, GLib.VariantType.BYTESTRING_ARRAY)?.dup_bytestring_array ();

    // The count of commands
    var cmd_arr_len = options.command.length;
    var cwd_arr_len = options.current_working_dir.length;
    options.command_cnt = cmd_arr_len > cwd_arr_len ? cmd_arr_len : cwd_arr_len;

    options.command.resize (options.command_cnt);
    options.current_working_dir.resize (options.command_cnt);

    // If "--" was present, the last '-c' option wasn't set
    string cmd_after_dd = string.joinv (" ", argv_after_dd);
    if (argv_after_dd != null) {
      if (options.command_cnt <= 0) {
        options.command[0] = cmd_after_dd;
        options.command_cnt = 1;
      } else {
        options.command[options.command_cnt - 1] = cmd_after_dd;
      }
    }
  }
}
